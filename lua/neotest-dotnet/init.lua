local lib = require("neotest.lib")
local logger = require("neotest.logging")
local async = require("neotest.async")
local Path = require("plenary.path")
local Tree = require("neotest.types").Tree
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")
local parser = require("neotest-dotnet.parser")
local result_utils = require("neotest-dotnet.result-utils")

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

    ;; Matches `[TestClass]`
    (class_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "TestClass" "TestFixture")
        )
      )
      name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Matches SpecFlow generated classes
    (class_declaration
      (attribute_list
        (attribute 
          (attribute_argument_list
            (attribute_argument
              (string_literal) @attribute_argument (#match? @attribute_argument "SpecFlow\"$")
            )
          )
        )
      ) 
      name: (identifier) @namespace.name
    ) @namespace.definition

    ;; --Test
    ;; Matches `[TestMethod]`
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "TestMethod" "Test" "TestCase" "Fact" "Theory")
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    (method_declaration
      (attribute_list
        (attribute
          name: (qualified_name) @attribute_name (#match? @attribute_name "SkippableFactAttribute$")
        )
      )
      name: (identifier) @test.name
    ) @test.definition
  ]]
  local tree = lib.treesitter.parse_positions(path, query, { nested_namespaces = true })
  return tree
end

DotnetNeotestAdapter.build_spec = function(args)
  local position = args.tree:data()
  local results_path = async.fn.tempname()
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

  -- Logs files to standard output of a trx file in the 'TestResults' directory at the project root
  local command = {
    "dotnet",
    "test",
    test_root,
    filter,
    "--logger",
    '"console;verbosity=detailed"',
  }

  local command_string = table.concat(command, " ")

  put(command_string)
  return {
    command = command_string,
    context = {
      pos_id = position.id,
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

---@async
---@param spec neotest.RunSpec
---@param b neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
DotnetNeotestAdapter.results = function(_, result, tree)
  local success, results = pcall(lib.files.read, result.output)

  if not success then
    logger.error("No test output file found ")
    return {}
  end

  local test_nodes = get_test_nodes_data(tree)
  local intermediate_results = result_utils.marshal_dotnet_console_output(results)
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
