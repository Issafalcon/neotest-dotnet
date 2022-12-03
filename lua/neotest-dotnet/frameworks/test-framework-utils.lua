local xunit_utils = require("neotest-dotnet.frameworks.xunit-utils")
local nunit_utils = require("neotest-dotnet.frameworks.nunit-utils")
local mstest_utils = require("neotest-dotnet.frameworks.mstest-utils")
local attribute_utils = require("neotest-dotnet.frameworks.test-attribute-utils")
local logger = require("neotest.logging")
local async = require("neotest.async")

local M = {}

--- Returns the utils module for the test framework being used, given the current file
---@return FrameworkUtils
function M.get_test_framework_utils(source, custom_attribute_args)
  local xunit_attributes = attribute_utils.attribute_match_list(custom_attribute_args, "xunit")
  local mstest_attributes = attribute_utils.attribute_match_list(custom_attribute_args, "mstest")
  local nunit_attributes = attribute_utils.attribute_match_list(custom_attribute_args, "nunit")

  local framework_query = [[
      (attribute
        name: (identifier) @attribute_name (#any-of? @attribute_name ]] .. xunit_attributes .. " " .. nunit_attributes .. " " .. mstest_attributes .. [[)
      )

      (attribute
        name: (qualified_name) @attribute_name (#match? @attribute_name "SkippableFactAttribute$")
      )

      (attribute
        name: (qualified_name) @attribute_name (#match? @attribute_name "TestMethodAttribute$")
      )

      (attribute
        name: (qualified_name) @attribute_name (#match? @attribute_name "TestAttribute$")
      )
  ]]

  async.util.scheduler()
  local root = vim.treesitter.get_string_parser(source, "c_sharp"):parse()[1]:root()
  local parsed_query = vim.treesitter.parse_query("c_sharp", framework_query)
  for _, captures in parsed_query:iter_matches(root, source) do
    local test_attribute = vim.treesitter.query.get_node_text(captures[1], source)
    if test_attribute then
      if
        string.find(xunit_attributes, test_attribute)
        or string.find(test_attribute, "SkippableFactAttribute")
      then
        return xunit_utils
      elseif
        string.find(nunit_attributes, test_attribute)
        or string.find(test_attribute, "TestAttribute")
      then
        return nunit_utils
      elseif
        string.find(mstest_attributes, test_attribute)
        or string.find(test_attribute, "TestMethodAttribute")
      then
        return mstest_utils
      else
        -- Default fallback
        return xunit_utils
      end
    end
  end
end

function M.get_match_type(captured_nodes)
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
  local match_type = M.get_match_type(captured_nodes)

  local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
  local definition = captured_nodes[match_type .. ".definition"]
  local node = {
    type = match_type,
    path = file_path,
    name = name,
    range = { definition:range() },
  }

  if match_type and match_type ~= "test.parameterized" then
    return node
  end

  return M.get_test_framework_utils(source)
    .build_parameterized_test_positions(node, source, captured_nodes, match_type)
end

return M
