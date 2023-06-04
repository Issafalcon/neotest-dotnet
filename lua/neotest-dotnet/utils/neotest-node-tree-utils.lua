local M = {}

--- Assuming a position_id of the form "C:\path\to\file.cs::namespace::class::method",
---   with the rule that the first :: is the separator between the file path and the rest of the position_id,
---   returns the '.' separated fully qualified name of the test, with each segment corresponding to the namespace, class, and method.
---@param position_id string The position_id of the neotest test node
---@return string The fully qualified name of the test
function M.get_qualified_test_name_from_id(position_id)
  local _, first_colon_end = string.find(position_id, ".cs::")
  local full_name = string.sub(position_id, first_colon_end + 1)
  full_name = string.gsub(full_name, "::", ".")
  return full_name
end

function M.get_test_nodes_data(tree)
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

return M
