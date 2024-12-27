local xunit = require("neotest-dotnet.xunit")
local nunit = require("neotest-dotnet.nunit")
local mstest = require("neotest-dotnet.mstest")

local async = require("neotest.async")

local M = {}

M.xunit_test_attributes = {
  "Fact",
  "Theory",
}

M.nunit_test_attributes = {
  "Test",
  "TestCase",
  "TestCaseSource",
}

M.mstest_test_attributes = {
  "TestMethod",
  "DataTestMethod",
}

M.specflow_test_attributes = {
  "SkippableFactAttribute",
  "Xunit.SkippableFactAttribute",
  "TestMethodAttribute",
  "TestAttribute",
  "NUnit.Framework.TestAttribute",
}

M.all_test_attributes = vim.fn.has("nvim-0.11") == 1
    and vim
      .iter({
        M.xunit_test_attributes,
        M.nunit_test_attributes,
        M.mstest_test_attributes,
        M.specflow_test_attributes,
      })
      :flatten()
      :totable()
  or vim.tbl_flatten({
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
    attribute_match_list = vim.fn.has("nvim-0.11") == 1
        and vim.iter({ attribute_match_list, custom_attribute_args[framework] }):flatten():totable()
      or vim.tbl_flatten({ attribute_match_list, custom_attribute_args[framework] })
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

function M.get_test_framework_utils_from_source(source, custom_attribute_args)
  local xunit_attributes = M.attribute_match_list(custom_attribute_args, "xunit")
  local mstest_attributes = M.attribute_match_list(custom_attribute_args, "mstest")
  local nunit_attributes = M.attribute_match_list(custom_attribute_args, "nunit")

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

  async.scheduler()
  local root = vim.treesitter.get_string_parser(source, "c_sharp"):parse()[1]:root()
  local parsed_query = vim.fn.has("nvim-0.9.0") == 1
      and vim.treesitter.query.parse("c_sharp", framework_query)
    or vim.treesitter.parse_query("c_sharp", framework_query)
  for _, captures, _ in parsed_query:iter_matches(root, source, nil, nil, { all = false }) do
    local test_attribute = vim.fn.has("nvim-0.9.0") == 1
        and vim.treesitter.get_node_text(captures[1], source)
      or vim.treesitter.query.get_node_text(captures[1], source)
    if test_attribute then
      if
        string.find(xunit_attributes, test_attribute)
        or string.find(test_attribute, "SkippableFactAttribute")
      then
        return xunit
      elseif
        string.find(nunit_attributes, test_attribute)
        or string.find(test_attribute, "TestAttribute")
      then
        return nunit
      elseif
        string.find(mstest_attributes, test_attribute)
        or string.find(test_attribute, "TestMethodAttribute")
      then
        return mstest
      else
        -- Default fallback
        return xunit
      end
    end
  end
end

function M.get_test_framework_utils_from_tree(tree)
  for _, node in tree:iter_nodes() do
    local framework = node:data().framework
    if framework == "xunit" then
      return xunit
    elseif framework == "nunit" then
      return nunit
    elseif framework == "mstest" then
      return mstest
    end
  end

  -- Default fallback (no test nodes anyway)
  return xunit
end

return M
