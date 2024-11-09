local nio = require("nio")
local lib = require("neotest.lib")
local logger = require("neotest.logging")

local vstest = require("neotest-dotnet.vstest_wrapper")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }
local dap = { adapter_name = "netcoredbg" }

local function get_script(script_name)
  local script_paths = vim.api.nvim_get_runtime_file(script_name, true)
  for _, path in ipairs(script_paths) do
    if vim.endswith(path, ("neotest-dotnet%s" .. script_name):format(lib.files.sep)) then
      return path
    end
  end
end

local function test_discovery_args(test_application_dll)
  local test_discovery_script = get_script("parse_tests.fsx")
  local testhost_dll = "/usr/local/share/dotnet/sdk/8.0.401/vstest.console.dll"

  return { "fsi", test_discovery_script, testhost_dll, test_application_dll }
end

local function run_test_command(id, stream_path, output_path, test_application_dll)
  local test_discovery_script = get_script("run_tests.fsx")
  local testhost_dll = "/usr/local/share/dotnet/sdk/8.0.401/vstest.console.dll"

  return {
    "dotnet",
    "fsi",
    "--exec",
    "--nologo",
    "--shadowcopyreferences+",
    test_discovery_script,
    testhost_dll,
    stream_path,
    output_path,
    id,
    test_application_dll,
  }
end

DotnetNeotestAdapter.root = function(path)
  return lib.files.match_root_pattern("*.sln")(path)
    or lib.files.match_root_pattern("*.[cf]sproj")(path)
end

DotnetNeotestAdapter.is_test_file = function(file_path)
  return vim.endswith(file_path, ".cs") or vim.endswith(file_path, ".fs")
end

DotnetNeotestAdapter.filter_dir = function(name)
  return name ~= "bin" and name ~= "obj"
end

local fsharp_query = [[
(namespace
    name: (long_identifier) @namespace.name
) @namespace.definition

(anon_type_defn
   (type_name (identifier) @namespace.name)
) @namespace.definition

(named_module
    name: (long_identifier) @namespace.name
) @namespace.definition

(module_defn
    (identifier) @namespace.name
) @namespace.definition

(declaration_expression
  (function_or_value_defn
    (function_declaration_left 
      .
      (_) @test.name)
    body: (_) @test.definition))

(member_defn
  (method_or_prop_defn
    (property_or_ident
       (identifier) @test.name .)
    .
    (_)
    .
    (_) @test.definition)) 
]]

local cache = {}

-- local function discover_tests(proj_dll_path)
--   local open_err, file_fd = nio.uv.fs_open(proj_dll_path, "r", 444)
--   assert(not open_err, open_err)
--   local stat_err, stat = nio.uv.fs_fstat(file_fd)
--   assert(not stat_err, stat_err)
--   nio.uv.fs_close(file_fd)
--   cache[proj_dll_path] = cache[proj_dll_path] or {}
--   if cache.last_cached == nil or cache.last_cached < stat.mtime.sec then
--     local discovery = vstest.discover_tests
--     cache[proj_dll_path].data = vim.json.decode(discovery.stdout.read())
--     cache[proj_dll_path].last_cached = stat.mtime.sec
--     discovery.close()
--   end
--   return cache[proj_dll_path].data
-- end

local function get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
  end
end

local proj_file_path_map = {}

local function get_proj_file(path)
  if proj_file_path_map[path] then
    return proj_file_path_map[path]
  end

  local proj_file = vim.fs.find(function(name, _)
    return name:match("%.[cf]sproj$")
  end, { type = "file", path = vim.fs.dirname(path) })[1]

  -- local dir_name = vim.fs.dirname(proj_file)
  -- local proj_name = vim.fn.fnamemodify(proj_file, ":t:r")
  --
  -- local proj_dll_path =
  --   vim.fs.find(proj_name .. ".dll", { upward = false, type = "file", path = dir_name })[1]
  --
  proj_file_path_map[path] = proj_file
  return proj_file
end

---@param path any The path to the file to discover positions in
---@return neotest.Tree
DotnetNeotestAdapter.discover_positions = function(path)
  local filetype = (vim.endswith(path, ".fs") and "fsharp") or "c_sharp"
  local proj_dll_path = get_proj_file(path)

  local tests_in_file = vim
    .iter(vstest.discover_tests(proj_dll_path))
    :map(function(_, v)
      return v
    end)
    :filter(function(test)
      return test.CodeFilePath == path
    end)
    :totable()

  logger.debug("filtered test cases:")
  logger.debug(tests_in_file)

  local tree

  ---@return nil | neotest.Position | neotest.Position[]
  local function build_position(source, captured_nodes)
    local match_type = get_match_type(captured_nodes)
    if match_type then
      local definition = captured_nodes[match_type .. ".definition"]

      local positions = {}

      if match_type == "test" then
        for _, test in ipairs(tests_in_file) do
          if test.LineNumber == definition:start() + 1 then
            table.insert(positions, {
              id = test.Id,
              type = match_type,
              path = path,
              name = test.DisplayName,
              qualified_name = test.FullyQualifiedName,
              proj_dll_path = test.Source,
              range = { definition:range() },
            })
          end
        end
      else
        local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
        table.insert(positions, {
          type = match_type,
          path = path,
          name = string.gsub(name, "``", ""),
          proj_dll_path = proj_dll_path,
          range = { definition:range() },
        })
      end
      return positions
    end
  end

  if #tests_in_file > 0 then
    local content = lib.files.read(path)
    local lang = vim.treesitter.language.get_lang(filetype) or filetype
    nio.scheduler()
    local lang_tree =
      vim.treesitter.get_string_parser(content, lang, { injections = { [lang] = "" } })

    local root = lib.treesitter.fast_parse(lang_tree):root()

    local query = lib.treesitter.normalise_query(lang, fsharp_query)

    local sep = lib.files.sep
    local path_elems = vim.split(path, sep, { plain = true })
    local nodes = {
      {
        type = "file",
        path = path,
        name = path_elems[#path_elems],
        range = { root:range() },
      },
    }
    for _, match in query:iter_matches(root, content, nil, nil, { all = false }) do
      local captured_nodes = {}
      for i, capture in ipairs(query.captures) do
        captured_nodes[capture] = match[i]
      end
      local res = build_position(content, captured_nodes)
      if res then
        for _, pos in ipairs(res) do
          nodes[#nodes + 1] = pos
        end
      end
    end

    tree = lib.positions.parse_tree(nodes, {
      nested_tests = true,
      require_namespaces = false,
      position_id = function(position, parents)
        return position.id
          or vim
            .iter({
              position.path,
              vim.tbl_map(function(pos)
                return pos.name
              end, parents),
              position.name,
            })
            :flatten()
            :join("::")
      end,
    })
  end

  return tree
end

---@summary Neotest core interface method: Build specs for running tests
---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
DotnetNeotestAdapter.build_spec = function(args)
  local results_path = nio.fn.tempname()
  local stream_path = nio.fn.tempname()
  lib.files.write(stream_path, "")

  local stream_data, stop_stream = lib.files.stream_lines(stream_path)

  local tree = args.tree
  if not tree then
    return
  end

  local pos = args.tree:data()

  if pos.type ~= "test" then
    return
  end

  return {
    command = { "dotnet", "build" },
    context = {
      result_path = results_path,
      stop_stream = stop_stream,
      file = pos.path,
      id = pos.id,
    },
    stream = function()
      vstest.run_tests(pos.id, stream_path, results_path)
      return function()
        local lines = stream_data()
        local results = {}
        for _, line in ipairs(lines) do
          local result = vim.json.decode(line, { luanil = { object = true } })
          results[result.id] = result.result
        end
        return results
      end
    end,
  }
end

---@async
---@param spec neotest.RunSpec
---@param run neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
DotnetNeotestAdapter.results = function(spec, run, tree)
  local max_wait = 5 * 60 * 1000 -- 5 min
  local success, data = pcall(vstest.spin_lock_wait_file, spec.context.result_path, max_wait)

  spec.context.stop_stream()

  local results = {}

  if not success then
    local outcome = "skipped"
    results[spec.context.id] = {
      status = outcome,
      errors = {
        message = "failed to read result file: " .. data,
      },
    }

    return results
  end

  local parse_ok, parsed = pcall(vim.json.decode, data)
  assert(parse_ok, "failed to parse result file")

  if not parse_ok then
    local outcome = "skipped"
    results[spec.context.id] = {
      status = outcome,
      errors = {
        message = "failed to parse result file",
      },
    }

    return results
  end

  return parsed
end

setmetatable(DotnetNeotestAdapter, {
  __call = function(_, opts)
    if type(opts.dap) == "table" then
      for k, v in pairs(opts.dap) do
        dap[k] = v
      end
    end
    if type(opts.custom_attributes) == "table" then
      custom_attribute_args = opts.custom_attributes
    end
    if type(opts.dotnet_additional_args) == "table" then
      dotnet_additional_args = opts.dotnet_additional_args
    end
    if type(opts.discovery_root) == "string" then
      discovery_root = opts.discovery_root
    end

    local function find_runsettings_files()
      local files = {}
      for _, runsettingsFile in
        ipairs(vim.fn.glob(vim.fn.getcwd() .. "**/*.runsettings", false, true))
      do
        table.insert(files, runsettingsFile)
      end

      for _, runsettingsFile in
        ipairs(vim.fn.glob(vim.fn.getcwd() .. "**/.runsettings", false, true))
      do
        table.insert(files, runsettingsFile)
      end

      return files
    end

    local function select_runsettings_file()
      local files = find_runsettings_files()
      if #files == 0 then
        print("No .runsettings files found")
        vim.g.neotest_dotnet_runsettings_path = nil
        return
      end

      vim.ui.select(files, {
        prompt = "Select runsettings file:",
        format_item = function(item)
          return vim.fn.fnamemodify(item, ":p:.")
        end,
      }, function(choice)
        if choice then
          vim.g.neotest_dotnet_runsettings_path = choice
          print("Selected runsettings file: " .. choice)
        end
      end)
    end

    vim.api.nvim_create_user_command("NeotestSelectRunsettingsFile", select_runsettings_file, {})
    vim.api.nvim_create_user_command("NeotestClearRunsettings", function()
      vim.g.neotest_dotnet_runsettings_path = nil
    end, {})
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
