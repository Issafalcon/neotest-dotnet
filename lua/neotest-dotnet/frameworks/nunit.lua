local logger = require("neotest.logging")

---@type FrameworkUtils
local M = {}

function M.get_treesitter_queries(custom_attribute_args)
  return require("neotest-dotnet.tree-sitter.nunit-queries").get_queries(custom_attribute_args)
end

---Builds a position from captured nodes, optionally parsing parameters to create sub-positions.
---@param base_node table The initial root node to build the positions from
---@param source any
---@param captured_nodes any
---@param match_type string The type of node that was matched by the TS query
---@return table
M.build_parameterized_test_positions = function(base_node, source, captured_nodes, match_type)
  logger.debug("neotest-dotnet(NUnit Utils): Building parameterized test positions from source")
  logger.debug("neotest-dotnet(NUnit Utils): Base node: ")
  logger.debug(base_node)

  logger.debug("neotest-dotnet(NUnit Utils): Match Type: " .. match_type)

  local query = [[
    ;;query
    (attribute_list
      (attribute
        name: (identifier) @attribute_name (#any-of? @attribute_name "TestCase")
        ((attribute_argument_list) @arguments)
      )
    )
  ]]

  local param_query = vim.fn.has("nvim-0.9.0") == 1 and vim.treesitter.query.parse("c_sharp", query)
    or vim.treesitter.parse_query("c_sharp", query)

  -- Set type to test (otherwise it will be test.parameterized)
  local parameterized_test_node = vim.tbl_extend("force", base_node, { type = "test" })
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

  logger.debug("neotest-dotnet(NUnit Utils): Built parameterized test positions: ")
  logger.debug(nodes)

  return nodes
end

return M
