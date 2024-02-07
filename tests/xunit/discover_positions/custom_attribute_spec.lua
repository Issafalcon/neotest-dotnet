local async = require("nio").tests
local plugin = require("neotest-dotnet")

A = function(...)
  print(vim.inspect(...))
end

describe("discover_positions", function()
  require("neotest").setup({
    adapters = {
      require("neotest-dotnet")({
        custom_attributes = {
          xunit = { "SkippableEnvironmentFact" },
        },
      }),
    },
  })

  async.it(
    "should discover tests with custom attribute when no other xUnit tests are present",
    function()
      local spec_file = "./tests/xunit/specs/custom_attribute.cs"
      local spec_file_name = "custom_attribute.cs"
      local positions = plugin.discover_positions(spec_file):to_list()

      local function get_expected_output(file_path, file_name)
        return {
          {
            id = "./tests/xunit/specs/custom_attribute.cs",
            name = "custom_attribute.cs",
            path = "./tests/xunit/specs/custom_attribute.cs",
            range = { 0, 0, 16, 0 },
            type = "file",
          },
          {
            {
              id = "./tests/xunit/specs/custom_attribute.cs::XUnitSamples",
              is_class = false,
              name = "XUnitSamples",
              path = "./tests/xunit/specs/custom_attribute.cs",
              range = { 4, 0, 15, 1 },
              type = "namespace",
            },
            {
              {
                id = "./tests/xunit/specs/custom_attribute.cs::XUnitSamples::CosmosConnectorTest",
                is_class = true,
                name = "CosmosConnectorTest",
                path = "./tests/xunit/specs/custom_attribute.cs",
                range = { 6, 0, 15, 1 },
                type = "namespace",
              },
              {
                {
                  id = "./tests/xunit/specs/custom_attribute.cs::XUnitSamples::CosmosConnectorTest::Custom_Attribute_Tests",
                  is_class = false,
                  name = "Custom_Attribute_Tests",
                  path = "./tests/xunit/specs/custom_attribute.cs",
                  range = { 9, 4, 14, 5 },
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
