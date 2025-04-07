local nio = require("nio")
local lib = require("neotest.lib")
local types = require("neotest.types")
local logger = require("neotest.logging")

local vstest = require("neotest-dotnet.vstest")
local test_discovery = require("neotest-dotnet.vstest.discovery")
local cli_wrapper = require("neotest-dotnet.vstest.cli_wrapper")
local vstest_strategy = require("neotest-dotnet.strategies.vstest")
local dotnet_utils = require("neotest-dotnet.dotnet_utils")

--- @type dap.Configuration
local dap_settings = {
  type = "netcoredbg",
  name = "netcoredbg - attach",
  request = "attach",
  env = {
    DOTNET_ENVIRONMENT = "Development",
  },
  justMyCode = false,
}

---@package
---@type neotest.Adapter
---@diagnostic disable-next-line: missing-fields
local DotnetNeotestAdapter = { name = "neotest-dotnet" }

function DotnetNeotestAdapter.root(path)
  local solution_dir = lib.files.match_root_pattern("*.sln")(path)
    or lib.files.match_root_pattern("*.slnx")(path)

  if solution_dir then
    vstest.discover_solution_tests(solution_dir)
  end

  return solution_dir or lib.files.match_root_pattern("*.[cf]sproj")(path)
end

function DotnetNeotestAdapter.is_test_file(file_path)
  return (
    (vim.endswith(file_path, ".csproj") or vim.endswith(file_path, ".fsproj"))
    and test_discovery.discover_tests(file_path)
  )
    or (
      (vim.endswith(file_path, ".cs") or vim.endswith(file_path, ".fs"))
      and test_discovery.discover_tests(file_path)
    )
end

function DotnetNeotestAdapter.filter_dir(name)
  if name == "bin" or name == "obj" then
    return false
  end

  return true
end

local function get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
  end
end

local function build_structure(positions, namespaces, opts)
  ---@type neotest.Position
  local parent = table.remove(positions, 1)
  if not parent then
    return nil
  end
  parent.id = parent.type == "file" and parent.path or opts.position_id(parent, namespaces)
  local current_level = { parent }
  local child_namespaces = vim.list_extend({}, namespaces)
  if
    parent.type == "namespace"
    or parent.type == "parameterized"
    or (opts.nested_tests and parent.type == "test")
  then
    child_namespaces[#child_namespaces + 1] = parent
  end
  if not parent.range then
    return current_level
  end
  while true do
    local next_pos = positions[1]
    if not next_pos or (next_pos.range and not lib.positions.contains(parent, next_pos)) then
      -- Don't preserve empty namespaces
      if #current_level == 1 and parent.type == "namespace" then
        return nil
      end
      if opts.require_namespaces and parent.type == "test" and #namespaces == 0 then
        return nil
      end
      return current_level
    end

    if parent.type == "parameterized" then
      local pos = table.remove(positions, 1)
      current_level[#current_level + 1] = pos
    else
      local sub_tree = build_structure(positions, child_namespaces, opts)
      if opts.nested_tests or parent.type ~= "test" then
        current_level[#current_level + 1] = sub_tree
      end
    end
  end
end

---@param source string
---@param captured_nodes any
---@param tests_in_file table<string, TestCase>
---@param path string
---@return nil | neotest.Position | neotest.Position[]
local function build_position(source, captured_nodes, tests_in_file, path)
  local match_type = get_match_type(captured_nodes)
  if match_type then
    local definition = captured_nodes[match_type .. ".definition"]

    ---@type neotest.Position[]
    local positions = {}

    if match_type == "test" then
      for id, test in pairs(tests_in_file) do
        if
          definition:start() <= test.LineNumber - 1 and test.LineNumber - 1 <= definition:end_()
        then
          table.insert(positions, {
            id = id,
            type = match_type,
            path = path,
            name = test.DisplayName,
            qualified_name = test.FullyQualifiedName,
            range = { definition:range() },
          })
          tests_in_file[id] = nil
        end
      end
    else
      local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
      table.insert(positions, {
        type = match_type,
        path = path,
        name = string.gsub(name, "``", ""),
        range = { definition:range() },
      })
    end

    if #positions > 1 then
      local pos = positions[1]
      table.insert(positions, 1, {
        type = "parameterized",
        path = pos.path,
        -- remove parameterized part of test name
        name = pos.name:gsub("<.*>", ""):gsub("%(.*%)", ""),
        range = pos.range,
      })
    end

    return positions
  end
end

--- Some adapters do not provide the file which the test is defined in.
--- In those cases we nest the test cases under the solution file.
local function get_top_level_tests(project_path)
  local project = dotnet_utils.get_proj_info(project_path)

  if not project then
    return {}
  end

  local tests_in_file = test_discovery.discover_project_tests(project, project.dll_file)

  logger.debug(string.format("neotest-dotnet: top-level tests in file: %s", project.dll_file))

  if not tests_in_file or next(tests_in_file) == nil then
    return
  end

  local n = #tests_in_file

  local nodes = {
    {
      type = "file",
      path = project.proj_file,
      name = vim.fs.basename(project.proj_file),
      range = { 0, 0, n + 1, -1 },
    },
  }

  local i = 0

  -- add tests which does not have a matching tree-sitter node.
  for id, test in pairs(tests_in_file) do
    nodes[#nodes + 1] = {
      id = id,
      type = "test",
      path = project.proj_file,
      name = test.DisplayName,
      qualified_name = test.FullyQualifiedName,
      range = { i, 0, i + 1, -1 },
    }
    i = i + 1
  end

  local structure = assert(build_structure(nodes, {}, {
    nested_tests = false,
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
  }))

  return types.Tree.from_list(structure, function(pos)
    return pos.id
  end)
end

function DotnetNeotestAdapter.discover_positions(path)
  logger.info(string.format("neotest-dotnet: scanning %s for tests...", path))

  if vim.endswith(path, ".csproj") or vim.endswith(path, ".fsproj") then
    return get_top_level_tests(path)
  end

  local filetype = (vim.endswith(path, ".fs") and "fsharp") or "c_sharp"

  local tests_in_file = test_discovery.discover_tests(path)

  if not tests_in_file or next(tests_in_file) == nil then
    return
  end

  local tree

  if tests_in_file then
    local content = lib.files.read(path)
    nio.scheduler()
    tests_in_file = vim.fn.deepcopy(tests_in_file)
    local lang_tree =
      vim.treesitter.get_string_parser(content, filetype, { injections = { [filetype] = "" } })

    local root = lib.treesitter.fast_parse(lang_tree):root()

    local query = lib.treesitter.normalise_query(
      filetype,
      filetype == "fsharp" and require("neotest-dotnet.queries.fsharp")
        or require("neotest-dotnet.queries.c_sharp")
    )

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
      local res = build_position(content, captured_nodes, tests_in_file, path)
      if res then
        for _, pos in ipairs(res) do
          nodes[#nodes + 1] = pos
        end
      end
    end

    -- add tests which does not have a matching tree-sitter node.
    for id, test in pairs(tests_in_file) do
      nodes[#nodes + 1] = {
        id = id,
        type = "test",
        path = path,
        name = test.DisplayName,
        qualified_name = test.FullyQualifiedName,
        range = { test.LineNumber - 1, 0, test.LineNumber - 1, -1 },
      }
    end

    local structure = assert(build_structure(nodes, {}, {
      nested_tests = false,
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
    }))

    tree = types.Tree.from_list(structure, function(pos)
      return pos.id
    end)
  end

  logger.info(string.format("neotest-dotnet: done scanning %s for tests", path))

  return tree
end

function DotnetNeotestAdapter.build_spec(args)
  local tree = args.tree
  if not tree then
    return
  end

  local pos = args.tree:data()

  local ids = {}

  for _, position in tree:iter() do
    if position.type == "test" then
      ids[#ids + 1] = position.id
    end
  end

  logger.debug("neotest-dotnet: ids:")
  logger.debug(ids)

  local results_path = nio.fn.tempname()
  local stream_path = nio.fn.tempname()
  lib.files.write(stream_path, "")

  local stream_data, stop_stream = lib.files.stream_lines(stream_path)

  local strategy
  if args.strategy == "dap" then
    local attached_path = nio.fn.tempname()

    local pid = vstest.debug_tests(attached_path, stream_path, results_path, ids)
    --- @type dap.Configuration
    strategy = vim.tbl_extend("force", dap_settings, {
      cwd = dotnet_utils.get_proj_info(pos.path).proj_dir,
      processId = pid and vim.trim(pid),
      before = function()
        local dap = require("dap")
        dap.listeners.after.configurationDone["neotest-dotnet"] = function()
          nio.run(function()
            logger.debug("neotest-dotnet: attached to debug test runner")
            lib.files.write(attached_path, "1")
          end)
        end
      end,
    })
  end

  return {
    context = {
      result_path = results_path,
      stream_path = stream_path,
      stop_stream = stop_stream,
      ids = ids,
    },
    stream = function()
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
    strategy = strategy or vstest_strategy,
  }
end

function DotnetNeotestAdapter.results(spec, result, _tree)
  local max_wait = 5 * 50 * 1000 -- 5 min
  logger.info("neotest-dotnet: waiting for test results")
  local success, data = pcall(cli_wrapper.spin_lock_wait_file, spec.context.result_path, max_wait)

  spec.context.stop_stream()

  logger.info("neotest-dotnet: parsing test results")

  ---@type table<string, neotest.Result>
  local results = {}

  if not success then
    for _, id in ipairs(spec.context.ids) do
      results[id] = {
        status = types.ResultStatus.skipped,
        output = spec.context.result_path,
        errors = {
          { message = result.output },
          { message = "failed to read result file" },
        },
      }
    end
    return results
  end

  local parse_ok, parsed = pcall(vim.json.decode, data)
  assert(parse_ok, "failed to parse result file")

  if not parse_ok then
    for _, id in ipairs(spec.context.ids) do
      results[id] = {
        status = types.ResultStatus.skipped,
        output = spec.context.result_path,
        errors = {
          { message = result.output },
          { message = "failed to parse result file" },
        },
      }
    end

    return results
  end

  return parsed
end

---@class neotest-dotnet.Config
---@field sdk_path? string path to dotnet sdk. Example: /usr/local/share/dotnet/sdk/9.0.101/
---@field dap_settings? dap.Configuration dap settings for debugging

---@param opts neotest-dotnet.Config
local function apply_user_settings(_, opts)
  cli_wrapper.sdk_path = opts.sdk_path
  dap_settings = vim.tbl_extend("force", dap_settings, opts.dap_settings or {})
  return DotnetNeotestAdapter
end

setmetatable(DotnetNeotestAdapter, {
  __call = apply_user_settings,
})

return DotnetNeotestAdapter
