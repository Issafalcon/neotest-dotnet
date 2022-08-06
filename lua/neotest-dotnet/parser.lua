local async = require("neotest.async")

local Parser = {}

Parser.create_root_node = function(file_path)
  local file_dir = async.fn.fnamemodify(file_path, ":p:h")

  -- Create root 'dir' and 'file' tree nodes
  local node = {
    {
      id = file_dir,
      type = "dir",
      path = file_dir,
    },
    {
      {
        id = file_path,
        type = "file",
        path = file_path,
        name = file_path
      },
    },
  }

  return node
end


---Takes a code structure provided by the omnisharp lsp code_structure response and creates a tree of nodes
---which neotest can use to create a Tree. Recursively parses the children in the code_structure
---@param code_elements table The nested list of dotnet code elements to parse into nodes.
---@param node table The node to add additional nodes onto based on the provided code_elements
---@param file_path string The path to the file that the code_elements belong to.
---@param node_id any The id of the code element used to identify the Tree item in neotest
---@return table The list of nodes that neotest can use to create a Tree.
Parser.parse = function(code_elements, node, file_path, node_id)
  node_id = node_id or file_path

  for _, element in ipairs(code_elements) do
    local current_id = node_id .. "::" .. element.Name
    local namespace_node_index = 1

    if element.Kind and (element.Kind == "namespace" or element.Kind == "class") then
      -- Dotnet namespace display name is more appropriate than it's provided name. Otherwise,
      -- if it's a class, then the element name is more appropriate
      local position_name = element.Kind == "namespace" and element.DisplayName or element.Name

      -- Create namespace node at the next level down in the tree
      local namespace_node = {
        {
          id = current_id,
          type = "namespace",
          path = file_path,
          name = position_name,
          range = { element.Ranges.full.Start.Line, 0, element.Ranges.full.End.Line, 0 },
        },
      }

      namespace_node_index = #node + 1
      table.insert(node, namespace_node_index,  namespace_node)
    end

    -- Get the test method nodes
    if element.Properties
        and element.Properties.testMethodName
        and element.Properties.testFramework
    then
      local test_node =
      {
        id = current_id,
        type = "test",
        path = file_path,
        name = element.Name,
        range = { element.Ranges.full.Start.Line, 0, element.Ranges.full.End.Line, 0 },
      }

      table.insert(node, #node + 1, test_node)
    end

    if element.Children then
      -- If there are children, then we can assume the current node is a 'namespace' node (i.e. Class or Namespace in dotnet terminology)
      -- The children in the tree should be placed at the same level as the namespace node
      Parser.parse(element.Children, node[namespace_node_index], file_path, node_id)
    end
  end

  return node
end

return Parser
