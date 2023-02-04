local logger = require("neotest.logging")
local lib = require("neotest.lib")
local Path = require("plenary.path")
local async = require("neotest.async")

local BuildSpecUtils = {}

--- Takes a position id of the format such as: "C:\path\to\file.cs::namespace::class::method" (Windows) and returns the fully qualified name of the test.
---    The format may vary depending on the OS and the test framework, and whether the test has parameters. Other examples are:
---       "/home/user/repos/test-project/MyClassTests.cs::MyClassTests::MyTestMethod" (Linux)
---       "/home/user/repos/test-project/MyClassTests.cs::MyClassTests::MyParameterizedMethod(a: 1)" (Linux - Parameterized test)
---@param position_id string The position id to parse.
---@return string The fully qualified name of the test to be passed to the "dotnet test" command
function BuildSpecUtils.build_test_fqn(position_id)
  local segments = vim.split(position_id, "::")
  local fqn

  for _, segment in ipairs(segments) do
    if not (async.fn.has("win32") and segment == "C") then
      if not string.find(segment, ".cs$") then
        -- Remove any test parameters as these don't work well with the dotnet filter formatting.
        segment = segment:gsub("%b()", "")
        fqn = fqn and fqn .. "." .. segment or segment
      end
    end
  end

  return fqn
end

---Creates a single spec for neotest to run using the dotnet test CLI
---@param position table The position value of the neotest tree node
---@param proj_root string The path of the project root for this particular position
---@param filter_arg string The filter argument to pass to the dotnet test command
---@param additional_args string Any additional arguments to pass to the dotnet test command
---@return
function BuildSpecUtils.create_single_spec(position, proj_root, filter_arg, additional_args)
  local results_path = async.fn.tempname() .. ".trx"
  filter_arg = filter_arg or ""

  local command = {
    "dotnet",
    "test",
    proj_root,
    filter_arg,
    "--results-directory",
    vim.fn.fnamemodify(results_path, ":h"),
    "--logger",
    '"trx;logfilename=' .. vim.fn.fnamemodify(results_path, ":t:h") .. '"',
  }

  local command_string = table.concat(command, " ")

  logger.debug("neotest-dotnet: Running tests using command: " .. command_string)

  return {
    command = command_string,
    context = {
      results_path = results_path,
      file = position.path,
      id = position.id,
    },
  }
end

function BuildSpecUtils.create_specs(tree, specs)
  local position = tree:data()
  specs = specs or {}

  -- Adapted from https://github.com/nvim-neotest/neotest/blob/392808a91d6ee28d27cbfb93c9fd9781759b5d00/lua/neotest/lib/file/init.lua#L341
  if position.type == "dir" then
    -- Check to see if we are in a project root
    local proj_files = async.fn.glob(Path:new(position.path, "*.csproj").filename, true, true)
    logger.debug("neotest-dotnet: Found " .. #proj_files .. " project files in " .. position.path)

    if #proj_files >= 1 then
      logger.debug(proj_files)

      for _, p in ipairs(async.fn.glob(Path:new(position.path, "*.csproj").filename, true, true)) do
        if lib.files.exists(p) then
          local spec = BuildSpecUtils.create_single_spec(position, position.path)
          table.insert(specs, spec)
        end
      end
    else
      -- Not in a project root, so find all child dirs and recurse through them as well so we can
      -- add all the specs for all projects in the solution dir.
      for _, child in ipairs(tree:children()) do
        BuildSpecUtils.create_specs(child, specs)
      end
    end
  elseif position.type == "namespace" or position.type == "test" then
    -- Allow a more lenient 'contains' match for the filter, accepting tradeoff that it may
    -- also run tests with similar names. This allows us to run parameterized tests individually
    -- or as a group.
    local fqn = BuildSpecUtils.build_test_fqn(position.id)
    local filter = '--filter FullyQualifiedName~"' .. fqn .. '"'

    local proj_root = lib.files.match_root_pattern("*.csproj")(position.path)
    local spec = BuildSpecUtils.create_single_spec(position, proj_root, filter)
    table.insert(specs, spec)
  elseif position.type == "file" then
    local proj_root = lib.files.match_root_pattern("*.csproj")(position.path)

    local spec = BuildSpecUtils.create_single_spec(position, proj_root)
    table.insert(specs, spec)
  end

  return #specs < 0 and nil or specs
end

return BuildSpecUtils
