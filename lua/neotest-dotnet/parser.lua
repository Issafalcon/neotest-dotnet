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
      },
    },
  }

  return node
end
Parser.parse = function(code_elements, node, file_path, node_id)
  node_id = node_id or file_path

  for _, element in ipairs(code_elements) do
    local current_id = node_id .. "::" .. element.Name

    if element.Kind and (element.Kind == "namespace" or element.Kind == "class") then

      local namespace_node = {
        {
          id = current_id,
          type = "namespace",
          path = file_path,
          range = { element.Ranges.full.Start.Line, 0, element.Ranges.full.End.Line, 0 },
        },
      }

      table.insert(node, namespace_node, #node + 1)

      if element.Children then
        Parser.parse(code_elements.Children, namespace_node, file_path, current_id)
      end
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
        range = { element.Ranges.full.Start.Line, 0, element.Ranges.full.End.Line, 0 },
      }

      table.insert(node, test_node, #node + 1)
    end

    -- Don't include elements of other dotnet types, just pass on the children if there are any
    if element.Children then
      Parser.parse(element.Children, node, file_path, node_id)
    end
  end

  return node
end

return Parser
