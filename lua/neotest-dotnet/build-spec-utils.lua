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
    if not (vim.fn.has("win32") and segment == "C") then
      if not string.find(segment, ".cs$") then
        -- Remove any test parameters as these don't work well with the dotnet filter formatting.
        segment = segment:gsub("%b()", "")
        fqn = fqn and fqn .. "." .. segment or segment
      end
    end
  end

  return fqn
end

return BuildSpecUtils
