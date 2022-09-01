local lib = require("neotest.lib")
local logger = require("neotest.logging")
local async = require("neotest.async")
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")
local result_utils = require("neotest-dotnet.result-utils")
local specflow_queries = require("neotest-dotnet.tree-sitter.specflow-queries")
local unit_test_queries = require("neotest-dotnet.tree-sitter.unit-test-queries")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }

DotnetNeotestAdapter.root = lib.files.match_root_pattern("*.csproj", "*.fsproj")

DotnetNeotestAdapter.is_test_file = function(file_path)
  -- TODO: Add logging and test this function
  if vim.endswith(file_path, ".cs") or vim.endswith(file_path, ".fs") then
    async.util.scheduler()
    local tests = omnisharp_commands.get_tests_in_file(file_path)

    local is_test_file = tests ~= nil and #tests > 0
    return is_test_file
  else
    return false
  end
end

DotnetNeotestAdapter.discover_positions = function(path)
  local query = [[
    ;; --Namespaces
    ;; Matches namespace
    (namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition

  ]] .. unit_test_queries .. specflow_queries
  local tree = lib.treesitter.parse_positions(path, query, { nested_namespaces = true })
  return tree
end

DotnetNeotestAdapter.build_spec = function(args)
  local position = args.tree:data()
  local results_path = async.fn.tempname() .. ".trx"
  local fqn
  for segment in string.gmatch(position.id, "([^::]+)") do
    if not string.find(segment, ".cs$") then
      fqn = fqn and fqn .. "." .. segment or segment
    end
  end

  local project_dir = DotnetNeotestAdapter.root(position.path)

  -- This returns the directory of the .csproj or .fsproj file. The dotnet command works with the directory name, rather
  -- than the full path to the file.
  local test_root = project_dir

  local filter = ""
  if position.type == "namespace" then
    filter = '--filter "FullyQualifiedName~' .. fqn .. '"'
  end
  if position.type == "test" then
    filter = '--filter "FullyQualifiedName=' .. fqn .. '"'
  end

  local command = {
    "dotnet",
    "test",
    test_root,
    filter,
    "-r",
    vim.fn.fnamemodify(results_path, ":h"),
    "--logger",
    '"trx;logfilename=' .. vim.fn.fnamemodify(results_path, ":t:h") .. '"',
  }

  local command_string = table.concat(command, " ")

  return {
    command = command_string,
    context = {
      results_path = results_path,
      file = position.path,
    },
  }
end

local function get_test_nodes_data(tree)
  local test_nodes = {}
  for _, node in tree:iter_nodes() do
    if node:data().type == "test" then
      local test_node = {
        name = node:data().name,
        path = node:data().path,
        id = node:data().id,
      }
      table.insert(test_nodes, test_node)
    end
  end

  return test_nodes
end

local function remove_bom(str)
  if string.byte(str, 1) == 239 and string.byte(str, 2) == 187 and string.byte(str, 3) == 191 then
    str = string.sub(str, 4)
  end
  return str
end

---@async
---@param spec neotest.RunSpec
---@param b neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
DotnetNeotestAdapter.results = function(spec, result, tree)
  local output_file = spec.context.results_path
  local success, xml = pcall(lib.files.read, output_file)

  if not success then
    logger.error("No test output file found ")
    return {}
  end

  local no_bom_xml = remove_bom(xml)

  local ok, parsed_data = pcall(lib.xml.parse, no_bom_xml)
  if not ok then
    logger.error("Failed to parse test output:", output_file)
    return {}
  end

  local test_results = parsed_data.TestRun.Results

  if #test_results.UnitTestResult > 1 then
    test_results = test_results.UnitTestResult
  end

  if not test_results then
    return {}
  end

  local test_nodes = get_test_nodes_data(tree)
  local intermediate_results = result_utils.create_intermediate_results(test_results)
  local neotest_results =
    result_utils.convert_intermediate_results(intermediate_results, test_nodes)

  return neotest_results
end

setmetatable(DotnetNeotestAdapter, {
  __call = function()
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
