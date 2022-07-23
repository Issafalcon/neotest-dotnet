local lib = require("neotest.lib")
local logger = require("neotest.logging")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }

-- TODO: Test this works
-- Add support for other dotnet languages proj files
DotnetNeotestAdapter.root = lib.files.match_root_pattern(".csproj", ".fsproj")

DotnetNeotestAdapter.is_test_file = function(file_path)
  -- TODO: Use the omnisharp-lsp to get a list of test file names
  -- and compare them to the file_path passed in
end
