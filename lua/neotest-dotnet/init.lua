local lib = require("neotest.lib")
local logger = require("neotest.logging")
local async = require("neotest.async")
local Path = require("plenary.path")
local Tree = require("neotest.types").Tree
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")
local parser = require("neotest-dotnet.parser")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }

DotnetNeotestAdapter.root = lib.files.match_root_pattern("*.csproj", "*.fsproj")

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

DotnetNeotestAdapter.build_spec = function(args)
  local position = args.tree:data()
  -- local test_file_bufnr = vim.fn.bufnr(position.path)
  -- local csproj = omnisharp_commands.get_project(position.path, test_file_bufnr).result.MsBuildProject.Path

  if position.type == "dir" then
    return
  end

  -- This returns the directory of the .csproj or .fsproj file. The dotnet command works with the directory name, rather
  -- than the full path to the file.
  local project_dir = DotnetNeotestAdapter.root(position.path)

  -- Logs files to standard output of a trx file in the 'TestResults' directory at the project root
  local command = {
    "dotnet",
    "test",
    project_dir,
    "--logger",
    "trx",
    "--filter",
    '"FullyQualifiedName~' .. position.name .. '"'
  }
  local command_string = table.concat(command, " ");

  return {
    command = command_string,
    context = {
      pos_id = position.id,
    }
  }
end

setmetatable(DotnetNeotestAdapter, {
  __call = function()
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
