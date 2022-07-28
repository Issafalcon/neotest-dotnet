local lib = require("neotest.lib")
local logger = require("neotest.logging")
local Path = require("plenary.path")
local omnisharp_commands = require("neotest-dotnet.omnisharp-lsp.requests")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }

DotnetNeotestAdapter.root = lib.files.match_root_pattern(".csproj", ".fsproj")

DotnetNeotestAdapter.is_test_file = function(file_path)
  -- TODO: Add logging and test this function
  if vim.endswith(file_path, ".cs") or vim.endswith(file_path, ".fs") then
    local tests = omnisharp_commands.get_tests_in_file(file_path)
    return #tests > 0
  end

  return false
end

DotnetNeotestAdapter.discover_positions = function (path)
  -- TODO: Parse the code_structure obtained from the omnisharp_lsp into the appropraite tree structure
  -- Review how neoterst-vim-test parses into a tree structure (and then reverses it)
  local code_structure = omnisharp_commands.get_code_structure(path)
end

setmetatable(DotnetNeotestAdapter, {
  __call = function()
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
