local M = {}

M.xunit_test_attributes = {
  "Fact",
  "Theory",
}

M.nunit_test_attributes = {
  "Test",
  "TestCase",
}

M.mstest_test_attributes = {
  "TestMethod",
  "DataTestMethod",
}

M.specflow_test_attributes = {
  "SkippableFactAttribute",
  "TestMethodAttribute",
  "TestAttribute",
}

M.all_test_attributes = vim.tbl_flatten({
  M.xunit_test_attributes,
  M.nunit_test_attributes,
  M.mstest_test_attributes,
  M.specflow_test_attributes,
})

--- Gets a list of the standard and customized test attributes for xUnit, for use in a tree-sitter predicates
---@param custom_attribute_args table The user configured mapping of the custom test attributes
---@param framework string The name of the test framework
---@return
function M.attribute_match_list(custom_attribute_args, framework)
  local attribute_match_list = {}
  if framework == "xunit" then
    attribute_match_list = M.xunit_test_attributes
  end
  if framework == "mstest" then
    attribute_match_list = M.mstest_test_attributes
  end
  if framework == "nunit" then
    attribute_match_list = M.nunit_test_attributes
  end

  if custom_attribute_args and custom_attribute_args[framework] then
    vim.tbl_flatten({ attribute_match_list, custom_attribute_args[framework] })
  end

  return M.join_test_attributes(attribute_match_list)
end

function M.join_test_attributes(attributes)
  local joined_attributes = attributes
      and table.concat(
        vim.tbl_map(function(attribute)
          return '"' .. attribute .. '"'
        end, attributes),
        " "
      )
    or ""
  return joined_attributes
end

return M
