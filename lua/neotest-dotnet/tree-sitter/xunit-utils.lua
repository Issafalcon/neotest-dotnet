local M = {}

local function parameter_string_to_table(parameter_string)
  local params = {}
  for param in string.gmatch(parameter_string:gsub("[()]", ""), "([^,]+)") do
    -- Split string on whitespace separator and take last element (the param name)
    local type_identifier_split = vim.split(param, "%s")
    table.insert(params, type_identifier_split[#type_identifier_split])
  end

  return params
end

local function argument_string_to_table(arg_string)
  local args = {}
  for arg in string.gmatch(arg_string:gsub("[()]", ""), "([^, ]+)") do
    table.insert(args, arg)
  end

  return args
end

M.get_treesitter_query = function()
  return [[
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
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "Theory")
        )
      )
      name: (identifier) @test.parameterized.name
      parameters: (parameter_list
        (parameter
          name: (identifier)
        )*
      ) @parameter_list
    ) @test.parameterized.definition
  ]]
end

---Builds a position from captured nodes, optionally parsing parameters to create sub-positions.
---@param file_path any
---@param source any
---@param captured_nodes any
---@param match_type string The type of node that was matched by the TS query
---@return table
M.build_position = function(file_path, source, captured_nodes, match_type)
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

  local param_query = vim.treesitter.parse_query(
    "c_sharp",
    [[
      ;;query
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "InlineData")
          ((attribute_argument_list) @arguments)
        )
      )
    ]]
  )

  -- Set type to test (otherwise it will be test.parameterized)
  local parameterized_test_node = vim.tbl_extend("force", node, { type = "test" })
  local nodes = { parameterized_test_node }

  -- Test method has parameters, so we need to create a sub-position for each test case
  local capture_indices = {}
  for i, capture in ipairs(param_query.captures) do
    capture_indices[capture] = i
  end
  local arguments_index = capture_indices["arguments"]

  for _, match in param_query:iter_matches(captured_nodes[match_type .. ".definition"], source) do
    local params_text = vim.treesitter.get_node_text(captured_nodes["parameter_list"], source)
    local args_node = match[arguments_index]
    local args_text = vim.treesitter.get_node_text(args_node, source)
    local params_table = parameter_string_to_table(params_text)
    local args_table = argument_string_to_table(args_text)

    local named_params = ""
    for i, param in ipairs(params_table) do
      named_params = named_params .. param .. ": " .. args_table[i]
      if i ~= #params_table then
        named_params = named_params .. ", "
      end
    end

    nodes[#nodes + 1] = vim.tbl_extend("force", parameterized_test_node, {
      name = parameterized_test_node.name .. "(" .. named_params .. ")",
      range = { args_node:range() },
    })
  end

  return nodes
end

return M
