local lib = require("neotest.lib")
local logger = require("neotest.logging")
local Tree = require("neotest.types").Tree
local async = require("neotest.async")
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")
local result_utils = require("neotest-dotnet.result-utils")
local trx_utils = require("neotest-dotnet.trx-utils")
local xunit_utils = require("neotest-dotnet.tree-sitter.xunit-utils")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }

---@class ParameterizedTestMethod
---@field name string
---@field range table
---@field parameters string

---@class ParameterizedTestCase
---@field range table
---@field arguments string

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

---Similar to the core neotest function, but simplified to replace test level nodes
---@param tree neotest.Tree
---@param node neotest.Tree
local function replace_node(tree, node)
  local existing = tree:get_key(node:data().id)
  if not existing then
    logger.error("Could not find node to replace", node:data())
  end

  -- Find parent node and replace child reference
  local parent = existing:parent()
  if not parent then
    -- If there is no parent, then the tree describes the same position as node,
    -- and is replaced in its entirety
    tree._children = node._children
    tree._nodes = node._nodes
    tree._data = node._data
    return
  end

  for i, child in pairs(parent._children) do
    if node:data().id == child:data().id then
      parent._children[i] = node
      break
    end
  end
  node._parent = parent

  -- Remove node and all descendants
  for _, pos in existing:iter() do
    tree._nodes[pos.id] = nil
  end

  -- Replace nodes map in new node and descendants
  for _, n in node:iter_nodes() do
    tree._nodes[n:data().id] = n
    n._nodes = tree._nodes
  end
end

---Implementation of core neotest function.
---@param path any
---@return neotest.Tree
DotnetNeotestAdapter.discover_positions = function(path)
  ---@type table<string, ParameterizedTestMethod>
  local parameterized_test_methods = {}
  ---@type ParameterizedTestCase[]
  local parameterized_test_cases = {}

  local function custom_build_position(file_path, source, captured_nodes)
    -- TODO: Implement strategy pattern for different test frameworks
    -- using omnisharp to determine the test runner being used
    return xunit_utils.build_position(
      file_path,
      source,
      captured_nodes,
      parameterized_test_methods,
      parameterized_test_cases
    )
  end

  local query = [[
    ;; --Namespaces
    ;; Matches namespace
    (namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition

    ;; Matches file-scoped namespaces
    (file_scoped_namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition
  ]] .. xunit_utils.get_treesitter_test_query()

  local tree = lib.treesitter.parse_positions(path, query, {
    nested_namespaces = true,
    nested_tests = true,
    build_position = custom_build_position,
  })

  local replacement_nodes =
  xunit_utils.create_replacement_parameterized_test_node(
    parameterized_test_methods,
    parameterized_test_cases,
    get_test_nodes_data(tree)
  )

  for _, node_replacement in ipairs(replacement_nodes) do
    local new_node = Tree.from_list(node_replacement.new_node, function(pos)
      return pos.id
    end)
    replace_node(tree, new_node)
  end

  return tree
end

DotnetNeotestAdapter.build_spec = function(args)
  local position = args.tree:data()
  local results_path = async.fn.tempname() .. ".trx"
  local fqn
  local segments = vim.split(position.id, "::")
  for _, segment in ipairs(segments) do
    if not (vim.fn.has("win32") and segment == "C") then
      if not string.find(segment, ".cs$") then

        -- Remove any test parameters as these don't work well with the dotnet filter formatting.
        segment = segment:gsub('%b()', '')
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
    filter = '--filter FullyQualifiedName~"' .. fqn .. '"'
  end
  if position.type == "test" then
    -- Allow a more lenient 'contains' match for the filter, accepting tradeoff that it may
    -- also run tests with similar names. This allows us to run parameterized tests individually
    -- or as a group.
    filter = '--filter FullyQualifiedName~"' .. fqn .. '"'
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

---@async
---@param spec neotest.RunSpec
---@param _ neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
DotnetNeotestAdapter.results = function(spec, _, tree)
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
