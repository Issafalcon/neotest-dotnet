local lib = require("neotest.lib")
local logger = require("neotest.logging")
local async = require("neotest.async")
local Path = require("plenary.path")
local Tree = require("neotest.types").Tree
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")
local parser = require("neotest-dotnet.parser")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }

DotnetNeotestAdapter.root = lib.files.match_root_pattern("csproj", "fsproj")

DotnetNeotestAdapter.is_test_file = function(file_path)
  -- TODO: Add logging and test this function
  if vim.endswith(file_path, ".cs") or vim.endswith(file_path, ".fs") then
    async.util.scheduler()
    local tests = omnisharp_commands.get_tests_in_file(file_path)

    local is_test_file = #tests > 0
    return is_test_file
  else
    return false
  end
end

DotnetNeotestAdapter.discover_positions = function(path)
  local code_structure = omnisharp_commands.get_code_structure(path)
  local root_node = parser.create_root_node(path)
  local parsed_list = parser.parse(code_structure.Elements, root_node[2], path)
  local tree = Tree.from_list(parsed_list, function(pos)
    return pos.id
  end)

  return tree
end

setmetatable(DotnetNeotestAdapter, {
  __call = function()
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
