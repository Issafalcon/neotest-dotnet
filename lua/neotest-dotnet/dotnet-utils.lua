local dotnet_utils = {}

function dotnet_utils.get_fqn_from_id(node_id)
  local fqn
  for segment in string.gmatch(node_id, "([^::]+)") do
    if not string.find(segment, ".cs$") then
      fqn = fqn and fqn .. "." .. segment or segment
    end
  end

  return fqn
end

function dotnet_utils.create_fqn_filter(position, fqn)
  local filter = ""
  if position.type == "file" then
    -- TODO: Filename not specific enough to filter on with the match expression. Can be more robust depending on the
    --      available filter expressions of the framework
    filter = '--filter "FullyQualifiedName~' .. vim.fn.fnamemodify(position.name, ":r") .. '"'
  end
  if position.type == "namespace" then
    -- TODO: Namespace not specific enough, but will currenty run tests in namespaces with similar name
    --     Better to figure out the test framework and then filter based on available filtering criteria for that specific framework
    filter = '--filter "FullyQualifiedName~' .. fqn .. '"'
  end
  if position.type == "test" then
    filter = '--filter "FullyQualifiedName=' .. fqn .. '"'
  end

  return filter
end

return dotnet_utils
