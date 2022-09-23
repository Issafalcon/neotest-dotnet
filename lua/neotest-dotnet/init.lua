local lib = require("neotest.lib")
local logger = require("neotest.logging")
local Tree = require("neotest.types").Tree
local positions = require("neotest.lib.positions")
local async = require("neotest.async")
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")
local result_utils = require("neotest-dotnet.result-utils")
local trx_utils = require("neotest-dotnet.trx-utils")
local parameterized_unit_test_queries = require("neotest-dotnet.tree-sitter.xunit-utils")

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

local function get_test_nodes_data(tree)
  local test_nodes = {}
  for _, node in tree:iter_nodes() do
    if node:data().type == "test" then
      table.insert(test_nodes, node)
    end
  end

  return test_nodes
end

DotnetNeotestAdapter.discover_positions = function(path)
  local code_structure = omnisharp_commands.get_code_structure(path)
  local parameterized_tests = {}
  -- put("Code structure")
  -- put(code_structure)

  local function custom_build_position(file_path, source, captured_nodes)
    local position = parameterized_unit_test_queries.build_position_and_extract_parameterized(
      file_path,
      source,
      captured_nodes,
      function(method)
        parameterized_tests[method.name] = method
      end
    )

    if position then
      return position
    end
  end

  local function custom_build_position_for_test_cases(file_path, source, captured_nodes)
    parameterized_unit_test_queries.extract_test_cases(
      file_path,
      source,
      captured_nodes,
      parameterized_tests
    )
  end

  local query = [[
    ;; --Namespaces
    ;; Matches namespace
    (namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition

  ]] .. parameterized_unit_test_queries.get_treesitter_test_query()

  local tree = lib.treesitter.parse_positions(path, query, {
    nested_namespaces = true,
    build_position = custom_build_position,
  })

  lib.treesitter.parse_positions(
    path,
    parameterized_unit_test_queries.get_parameterized_test_query(),
    {
      nested_namespaces = true,
      build_position = custom_build_position_for_test_cases,
    }
  )

  local nodes_to_replace =
    parameterized_unit_test_queries.create_replacement_parameterized_test_node(
      parameterized_tests,
      get_test_nodes_data(tree)
    )

  put(tree)
  for _, node_replacement in ipairs(nodes_to_replace) do
    local new_node = Tree.from_list(node_replacement.new_node, function(pos)
      return pos.id
    end)
    put(new_node)
    tree:add_child(node_replacement.node_key, new_node)
  end

  return tree
end

DotnetNeotestAdapter.build_spec = function(args)
  local position = args.tree:data()
  local results_path = async.fn.tempname() .. ".trx"
  local fqn
  for segment in string.gmatch(position.id, "([^::]+)") do
    if not (vim.fn.has("win32") and segment == "C") then
      if not string.find(segment, ".cs$") then
        fqn = fqn and fqn .. "." .. segment or segment
      end
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
      id = position.id,
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

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
DotnetNeotestAdapter.results = function(spec, result, tree)
  local output_file = spec.context.results_path

  local parsed_data = trx_utils.parse_trx(output_file)
  local test_results = parsed_data.TestRun and parsed_data.TestRun.Results

  -- No test results. Something went wrong. Check for runtime error
  if not test_results then
    return result_utils.get_runtime_error(spec.context.id)
  end

  if #test_results.UnitTestResult > 1 then
    test_results = test_results.UnitTestResult
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
