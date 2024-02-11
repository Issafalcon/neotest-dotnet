local xunit = require("neotest-dotnet.frameworks.xunit")
local nunit = require("neotest-dotnet.frameworks.nunit")
local mstest = require("neotest-dotnet.frameworks.mstest")
local attributes = require("neotest-dotnet.frameworks.test-attributes")
local async = require("neotest.async")

local TestFrameworkBase = {}

--- Returns the utils module for the test framework being used, given the current file
---@return FrameworkUtils
function TestFrameworkBase.get_test_framework_utils(source, custom_attribute_args)
  local xunit_attributes = attributes.attribute_match_list(custom_attribute_args, "xunit")
  local mstest_attributes = attributes.attribute_match_list(custom_attribute_args, "mstest")
  local nunit_attributes = attributes.attribute_match_list(custom_attribute_args, "nunit")

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
  for _, captures in parsed_query:iter_matches(root, source) do
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

function TestFrameworkBase.get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
  end
  if captured_nodes["class.name"] then
    return "class"
  end
  if captured_nodes["test.parameterized.name"] then
    return "test.parameterized"
  end
end

function TestFrameworkBase.position_id(position, parents)
  local original_id = position.path
  local has_parent_class = false
  local sep = "::"

  -- Build the original ID from the parents, changing the separator to "+" if any nodes are nested classes
  for _, node in ipairs(parents) do
    if has_parent_class and node.is_class then
      sep = "+"
    end

    if node.is_class then
      has_parent_class = true
    end

    original_id = original_id .. sep .. node.name
  end

  -- Add the final leaf nodes name to the ID, again changing the separator to "+" if it is a nested class
  sep = "::"
  if has_parent_class and position.is_class then
    sep = "+"
  end
  original_id = original_id .. sep .. position.name

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
function TestFrameworkBase.build_position(file_path, source, captured_nodes)
  local match_type = TestFrameworkBase.get_match_type(captured_nodes)

  local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
  local display_name = nil

  if captured_nodes["display_name"] then
    display_name = vim.treesitter.get_node_text(captured_nodes["display_name"], source)
  end

  local definition = captured_nodes[match_type .. ".definition"]

  -- Introduce the C# concept of a "class" to the node, so we can distinguish between a class and a namespace.
  --  Helps to determine if classes are nested, and therefore, if we need to modify the ID of the node (nested classes denoted by a '+' in C# test naming convention)
  local is_class = match_type == "class"

  -- Swap the match type back to "namespace" so neotest core can handle it properly
  if match_type == "class" then
    match_type = "namespace"
  end

  local node = {
    type = match_type,
    is_class = is_class,
    display_name = display_name,
    path = file_path,
    name = name,
    range = { definition:range() },
  }

  if match_type and match_type ~= "test.parameterized" then
    return node
  end

  return TestFrameworkBase.get_test_framework_utils(source)
    .build_parameterized_test_positions(node, source, captured_nodes, match_type)
end

--- Assuming a position_id of the form "C:\path\to\file.cs::namespace::class::method",
---   with the rule that the first :: is the separator between the file path and the rest of the position_id,
---   returns the '.' separated fully qualified name of the test, with each segment corresponding to the namespace, class, and method.
---@param position_id string The position_id of the neotest test node
---@return string The fully qualified name of the test
function TestFrameworkBase.get_qualified_test_name_from_id(position_id)
  local _, first_colon_end = string.find(position_id, ".cs::")
  local full_name = string.sub(position_id, first_colon_end + 1)
  full_name = string.gsub(full_name, "::", ".")
  return full_name
end

function TestFrameworkBase.get_test_nodes_data(tree)
  local test_nodes = {}
  for _, node in tree:iter_nodes() do
    if node:data().type == "test" then
      table.insert(test_nodes, node)
    end
  end

  -- Add an additional full_name property to the test nodes
  for _, node in ipairs(test_nodes) do
    local full_name = M.get_qualified_test_name_from_id(node:data().id)
    node:data().full_name = full_name
  end

  return test_nodes
end
return TestFrameworkBase
