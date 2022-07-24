local lib = require("neotest.lib")
local logger = require("neotest.logging")
local Path = require("plenary.path")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }

-- TODO: Test this works
-- Add support for other dotnet languages proj files
DotnetNeotestAdapter.root = lib.files.match_root_pattern(".csproj", ".fsproj")

DotnetNeotestAdapter.is_test_file = function(file_path)
  if not vim.endswith(file_path, ".cs") or not vim.endswith(file_path, ".fs") then
    return false
  end
  -- local elems = vim.split(file_path, Path.path.sep)
  -- local file_name = elems[#elems]

  -- TODO: Use the omnisharp-lsp to check if there are any tests in the file

end
