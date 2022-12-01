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

function M.xunit_attribute_matcher(custom_attribute_args)
  local combined_attr_list = {}
  if custom_attribute_args.xunit then
    for _, attr in ipairs(M.xunit_test_attributes) do
      table.insert(combined_attr_list, attr)
      vim.tbl_extend("force", combined_attr_list, custom_attribute_args.xunit[attr])
    end
  end

  return M.join_test_attributes(combined_attr_list)
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
