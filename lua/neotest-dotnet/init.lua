local nio = require("nio")
local lib = require("neotest.lib")
local logger = require("neotest.logging")

local vstest = require("neotest-dotnet.vstest_wrapper")

---@package
---@type neotest.Adapter
local DotnetNeotestAdapter = { name = "neotest-dotnet" }

DotnetNeotestAdapter.root = function(path)
  return lib.files.match_root_pattern("*.sln")(path)
    or lib.files.match_root_pattern("*.[cf]sproj")(path)
end

DotnetNeotestAdapter.is_test_file = function(file_path)
  return (vim.endswith(file_path, ".cs") or vim.endswith(file_path, ".fs"))
    and vstest.discover_tests(file_path)
end

DotnetNeotestAdapter.filter_dir = function(name)
  return name ~= "bin" and name ~= "obj"
end

local function get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
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
    return positions
  end
end

DotnetNeotestAdapter.discover_positions = function(path)
  logger.info(string.format("scanning %s for tests...", path))

  local fsharp_query = require("neotest-dotnet.queries.fsharp")
  local c_sharp_query = require("neotest-dotnet.queries.c_sharp")

  local filetype = (vim.endswith(path, ".fs") and "fsharp") or "c_sharp"

  local tests_in_file = vstest.discover_tests(path)

  local tree

  if tests_in_file then
    local content = lib.files.read(path)
    local lang = vim.treesitter.language.get_lang(filetype) or filetype
    nio.scheduler()
    local lang_tree =
      vim.treesitter.get_string_parser(content, lang, { injections = { [lang] = "" } })

    local root = lib.treesitter.fast_parse(lang_tree):root()

    local query =
      lib.treesitter.normalise_query(lang, filetype == "fsharp" and fsharp_query or c_sharp_query)

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
    -- TODO: invert logic so we loop test in tests_in_file rather than treesitter nodes.
    -- tests_in_file is our source of truth of test cases.
    -- the treesitter nodes are there to get the correct range for the test case.
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

  logger.info(string.format("done scanning %s for tests", path))

  return tree
end

DotnetNeotestAdapter.build_spec = function(args)
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

  logger.debug("ids:")
  logger.debug(ids)

  local results_path = nio.fn.tempname()
  local stream_path = nio.fn.tempname()
  lib.files.write(results_path, "")
  lib.files.write(stream_path, "")

  local stream_data, stop_stream = lib.files.stream_lines(stream_path)

  local strategy
  if args.strategy == "dap" then
    local pid_path = nio.fn.tempname()
    local attached_path = nio.fn.tempname()

    local pid = vstest.debug_tests(pid_path, attached_path, stream_path, results_path, pos.id)
    --- @type Configuration
    strategy = {
      type = "netcoredbg",
      name = "netcoredbg - attach",
      request = "attach",
      cwd = vstest.get_proj_info(pos.path).proj_dir,
      env = {
        DOTNET_ENVIRONMENT = "Development",
      },
      processId = pid,
      before = function()
        local dap = require("dap")
        dap.listeners.after.configurationDone["neotest-dotnet"] = function()
          nio.run(function()
            lib.files.write(attached_path, "1")
          end)
        end
      end,
    }
  end

  return {
    command = vstest.run_tests(ids, stream_path, results_path),
    context = {
      result_path = results_path,
      stop_stream = stop_stream,
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
    strategy = strategy,
  }
end

DotnetNeotestAdapter.results = function(spec)
  local max_wait = 5 * 50 * 1000 -- 5 min
  local success, data = pcall(vstest.spin_lock_wait_file, spec.context.result_path, max_wait)

  spec.context.stop_stream()

  local results = {}

  if not success then
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
  __call = function(_, _)
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
