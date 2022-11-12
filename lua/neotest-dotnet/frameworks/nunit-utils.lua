---@type FrameworkUtils
local M = {}

function M.get_treesitter_queries()
  return require("neotest-dotnet.tree-sitter.nunit-queries")
end

---Builds a position from captured nodes, optionally parsing parameters to create sub-positions.
---@param file_path any
---@param source any
---@param captured_nodes any
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
          name: (identifier) @attribute_name (#any-of? @attribute_name "TestCase")
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
    local args_node = match[arguments_index]
    local args_text = vim.treesitter.get_node_text(args_node, source):gsub("[()]", "")

    nodes[#nodes + 1] = vim.tbl_extend("force", parameterized_test_node, {
      name = parameterized_test_node.name .. "(" .. args_text .. ")",
      range = { args_node:range() },
    })
  end

  return nodes
end

return M
