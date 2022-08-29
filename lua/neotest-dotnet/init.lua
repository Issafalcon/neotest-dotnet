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
          name: (identifier) @attribute_name (#any-of? @attribute_name "TestClass")
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
          name: (identifier) @attribute_name (#any-of? @attribute_name TestMethod)
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
  local result_file_name = "neotest-" .. os.date("%Y%m%d-%H%M%S") .. ".trx"
  local result_path = Path:new(project_dir, "TestResults", result_file_name)

  -- This returns the directory of the .csproj or .fsproj file. The dotnet command works with the directory name, rather
  -- than the full path to the file.
  local test_root = project_dir

  local filter = ""
  if position.type == "dir" then
    return {}
  end
  if position.type == "file" then
    -- TODO: Filename not specific enough to filter on with the match expression. Can be more robust depending on the
    --      available filter expressions of the framework
    filter = '--filter "FullyQualifiedName~' .. vim.fn.fnamemodify(position.name, ":r") .. '"'
  end
  if position.type == "namespace" then
    -- TODO: Namespace not specific enough, but will currenty run tests in namespaces with similar name
    --     Better to figure out the test framework and then filter based on available filtering criteria for that specific framework
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

local function remove_bom(str)
  if string.byte(str, 1) == 239 and string.byte(str, 2) == 187 and string.byte(str, 3) == 191 then
    str = string.sub(str, 4)
  end
  return str
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
DotnetNeotestAdapter.results = function(spec, result, tree)
  -- From luarocks module

  local success, results = pcall(lib.files.read, result.output)
  local test_nodes = get_test_nodes_data(tree)

  if not success then
    logger.error("No test output file found ")
    return {}
  end

  if success then
    return result_utils.marshal_dotnet_console_output(results, get_test_nodes_data(tree))
  end

  -- local no_bom_xml = remove_bom(xml)
  local ok, parsed_data = pcall(lib.xml.parse, no_bom_xml)
  if not ok then
    logger.error("Failed to parse test output:", output_file)
    return {}
  end

  local neotest_results = {}
  local test_results = parsed_data.TestRun.Results

  if #test_results.UnitTestResult > 1 then
    test_results = test_results.UnitTestResult
  end

  if not test_results then
    return {}
  end

  local file_result = { status = "passed", errors = {} }
  for _, value in pairs(test_results) do
    if value._attr.testName ~= nil then
      local outcome = value._attr.outcome
      local pos_id = spec.context.file_path .. "::" .. value._attr.testName
      neotest_results[pos_id] = {
        status = string.lower(outcome),
        short = value._attr.testName .. ":" .. value._attr.outcome,
        -- output = value.Output and value.Output.StdOut or "Passed",
        errors = {},
      }

      if outcome == "Failed" then
        local failure_message = value.Output.ErrorInfo.Message
          .. "\n"
          .. value.Output.ErrorInfo.StackTrace
        -- neotest_results[pos_id].output = failure_message
        table.insert(neotest_results[pos_id].errors, {
          message = failure_message,
        })

        -- There is a failure, so set the overall file result status to failed and add errors
        file_result.status = "failed"
        vim.list_extend(file_result.errors, neotest_results[pos_id].errors)
      end
    end
  end

  neotest_results[spec.context.file_path] = file_result

  local function get_namespace_results(node)
    for parent in node:iter_parents() do
      if parent:data().type ~= "namespace" then
        neotest_results[parent:data().id] = file_result
      end
    end
  end

  for _, node in tree:iter_nodes() do
    if node:data().type == "test" then
      get_namespace_results(node)
    end
  end

  return neotest_results
end

setmetatable(DotnetNeotestAdapter, {
  __call = function()
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
