local async = require("nio").tests
local plugin = require("neotest-dotnet")

A = function(...)
  print(vim.inspect(...))
end

describe("discover_positions", function()
  require("neotest").setup({
    adapters = {
      require("neotest-dotnet"),
    },
  })

  async.it(
    "should discover tests with TestCaseSource attribute without creating nested parameterized tests",
    function()
      local spec_file = "./tests/nunit/specs/testcasesource.cs"
      local spec_file_name = "testcasesource.cs"
      local positions = plugin.discover_positions(spec_file):to_list()

      local function get_expected_output(file_path, file_name)
        return {
          {
            id = file_path,
            name = file_name,
            path = file_path,
            range = { 0, 0, 25, 0 },
            type = "file",
          },
          {
            {
              id = file_path .. "::NUnitSamples",
              is_class = false,
              name = "NUnitSamples",
              path = file_path,
              range = { 2, 0, 24, 1 },
              type = "namespace",
            },
            {
              {
                id = file_path .. "::NUnitSamples::Tests",
                is_class = true,
                name = "Tests",
                path = file_path,
                range = { 4, 0, 24, 1 },
                type = "namespace",
              },
              {
                {
                  id = file_path .. "::NUnitSamples::Tests::DivideTest",
                  is_class = false,
                  name = "DivideTest",
                  path = file_path,
                  range = { 12, 4, 16, 5 },
                  type = "test",
                },
              },
            },
          },
        }
      end

      assert.same(positions, get_expected_output(spec_file, spec_file_name))
    end
  )
end)
