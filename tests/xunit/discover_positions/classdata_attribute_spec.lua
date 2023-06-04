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
    "should discover tests with classdata attribute without creating nested parameterized tests",
    function()
      local spec_file = "./tests/xunit/specs/classdata.cs"
      local spec_file_name = "classdata.cs"
      local positions = plugin.discover_positions(spec_file):to_list()

      local function get_expected_output(file_path, file_name)
        return {
          {
            id = file_path,
            name = file_name,
            path = file_path,
            range = { 0, 0, 28, 0 },
            type = "file",
          },
          {
            {
              id = file_path .. "::XUnitSamples",
              is_class = false,
              name = "XUnitSamples",
              path = file_path,
              range = { 4, 0, 27, 1 },
              type = "namespace",
            },
            {
              {
                id = file_path .. "::XUnitSamples::ClassDataTests",
                is_class = true,
                name = "ClassDataTests",
                path = file_path,
                range = { 6, 0, 15, 1 },
                type = "namespace",
              },
              {
                {
                  id = file_path .. "::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test",
                  is_class = false,
                  name = "Theory_With_Class_Data_Test",
                  path = file_path,
                  range = { 8, 1, 14, 2 },
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
