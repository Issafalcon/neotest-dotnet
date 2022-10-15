local specflow_queries = require("neotest-dotnet.tree-sitter.specflow-queries")
local unit_test_queries = require("neotest-dotnet.tree-sitter.unit-test-queries")

local M = {}

M.test_case_prefix = "TestCase"

M.get_treesitter_test_query = function()
  return unit_test_queries
    .. specflow_queries
    .. [[
    ;; query
    ;; Matches XUnit test class (has no specific attributes on class)
    (
      (using_directive
        (identifier) @package_name (#eq? @package_name "Xunit")
      )
      [
        (namespace_declaration
          body: (declaration_list
            (class_declaration
              name: (identifier) @namespace.name
            ) @namespace.definition
          )
        )
        (file_scoped_namespace_declaration
          (class_declaration
            name: (identifier) @namespace.name
          ) @namespace.definition
        )
      ]
    )

    ;; Matches Xunit test class where using statement under namespace
    (
      [
        (namespace_declaration
          body: (declaration_list
            (using_directive
              (identifier) @package_name (#eq? @package_name "Xunit")
            )
            (class_declaration
              name: (identifier) @namespace.name
            ) @namespace.definition
          )
        )
        (file_scoped_namespace_declaration
          (using_directive
            (identifier) @package_name (#eq? @package_name "Xunit")
          )
          (class_declaration
            name: (identifier) @namespace.name
          ) @namespace.definition
        )
      ]
    )

    ;; Matches parameterized test methods
    (method_declaration
      name: (identifier) @test.name
      parameters: (parameter_list
        (parameter
          name: (identifier)
        )*
      ) @parameter_list
    ) @test.definition
  ]]
end

local function get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
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
    for segment in string.gmatch(original_id, "([^::]+)") do
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
  local param_query = vim.treesitter.parse_query(
    "c_sharp",
    [[
      ;;query
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "InlineData")
          ((attribute_argument_list) @parameters)
        )
      )
    ]]
  )
  local match_type = get_match_type(captured_nodes)
  local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
  local definition = captured_nodes[match_type .. ".definition"]

  local node = {
    type = match_type,
    path = file_path,
    name = name,
    range = { definition:range() },
  }
  if match_type ~= "test" then
    return node
  end

  local nodes = { node }

  local capture_indices = {}
  for i, capture in ipairs(param_query.captures) do
    capture_indices[capture] = i
  end
  local params_index = capture_indices["parameters"]

  for _, match in param_query:iter_matches(captured_nodes[match_type .. ".definition"], source) do
    local params_node = match[params_index]
    local params_text = vim.treesitter.get_node_text(params_node, source)
    nodes[#nodes + 1] = vim.tbl_extend(
      "force",
      node,
      { name = node.name .. params_text, range = { params_node:range() } }
    )
  end

  return nodes
end

return M
