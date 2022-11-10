local specflow_queries = require("neotest-dotnet.tree-sitter.specflow-queries")
local unit_test_queries = require("neotest-dotnet.tree-sitter.unit-test-queries")
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")
local xunit_utils = require("neotest-dotnet.tree-sitter.xunit-utils")
local nunit_utils = require("neotest-dotnet.tree-sitter.nunit-utils")
local logger = require("neotest.logging")

local M = {}

--- Returns the utils module for the test framework being used, given the current file
---@param path string The file path to assess to determin which test framework is being used
---@return FrameworkUtils
local function get_test_framework_utils(path)
  local framework_dictionary = {
    xunit = xunit_utils,
    nunit = nunit_utils,
  }
  local tests = omnisharp_commands.get_tests_in_file(path)
  local framework_Name = tests and tests[1].Properties.testFramework or "xunit" -- Assume xunit for now
  logger.debug("neotest-dotnet: Test framework detected as being " .. framework_Name)
  return framework_dictionary[framework_Name]
end

local function get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
  end
  if captured_nodes["test.parameterized.name"] then
    return "test.parameterized"
  end
end

M.test_case_prefix = "TestCase"

M.get_treesitter_test_query = function(path)
  local utils = get_test_framework_utils(path)
  local framework_query = utils.get_treesitter_query()
  return unit_test_queries .. specflow_queries .. framework_query
end

M.position_id = function(position, parents)
  local original_id = table.concat(
    vim.tbl_flatten({
      position.path,
      vim.tbl_map(function(pos)
        return pos.name
      end, parents),
      position.name,
    }),
    "::"
  )

  -- Check to see if the position is a test case and contains parentheses (meaning it is parameterized)
  -- If it is, remove the duplicated parent test name from the ID, so that when reading the trx test name
  -- it will be the same as the test name in the test explorer
  -- Example:
  --  When ID is "/path/to/test_file.cs::TestNamespace::TestClassName::ParentTestName::ParentTestName(TestName)"
  --  Then we need it to be converted to "/path/to/test_file.cs::TestNamespace::TestClassName::ParentTestName(TestName)"
  if position.type == "test" and position.name:find("%(") then
    local id_segments = {}
    for _, segment in ipairs(vim.split(original_id, "::")) do
      table.insert(id_segments, segment)
    end

    table.remove(id_segments, #id_segments - 1)
    return table.concat(id_segments, "::")
  end

  return original_id
end

---Builds a position from captured nodes, optionally parsing parameters to create sub-positions.
---@param file_path any
---@param source any
---@param captured_nodes any
---@return table
M.build_position = function(file_path, source, captured_nodes)
  local match_type = get_match_type(captured_nodes)
  return get_test_framework_utils(file_path).build_position(
    file_path,
    source,
    captured_nodes,
    match_type
  )
end

return M
