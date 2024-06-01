local async = require("nio").tests
local plugin = require("neotest-dotnet")
local DotnetUtils = require("neotest-dotnet.utils.dotnet-utils")
local stub = require("luassert.stub")

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

  before_each(function()
    stub(DotnetUtils, "get_test_full_names", function()
      return {
        is_complete = true,
        result = function()
          return {
            output = {
              "XUnitSamples.CosmosConnectorTest.Custom_Attribute_Tests",
            },
            result_code = 0,
          }
        end,
      }
    end)
  end)

  after_each(function()
    DotnetUtils.get_test_full_names:revert()
  end)

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
              framework = "xunit",
              id = "./tests/xunit/specs/custom_attribute.cs::CosmosConnectorTest",
              is_class = true,
              name = "CosmosConnectorTest",
              path = "./tests/xunit/specs/custom_attribute.cs",
              range = { 6, 0, 15, 1 },
              type = "namespace",
            },
            {
              {
                display_name = "Custom attribute works ok",
                framework = "xunit",
                id = "./tests/xunit/specs/custom_attribute.cs::CosmosConnectorTest::Custom_Attribute_Tests",
                is_class = false,
                name = "Custom_Attribute_Tests",
                path = "./tests/xunit/specs/custom_attribute.cs",
                range = { 9, 4, 14, 5 },
                type = "test",
              },
            },
          },
        }
        -- return {
        --   {
        --     id = "./tests/xunit/specs/custom_attribute.cs",
        --     name = "custom_attribute.cs",
        --     path = "./tests/xunit/specs/custom_attribute.cs",
        --     range = { 0, 0, 16, 0 },
        --     type = "file",
        --   },
        --   {
        --     {
        --       framework = "xunit",
        --       id = "./tests/xunit/specs/custom_attribute.cs::XUnitSamples",
        --       is_class = false,
        --       name = "XUnitSamples",
        --       path = "./tests/xunit/specs/custom_attribute.cs",
        --       range = { 4, 0, 15, 1 },
        --       type = "namespace",
        --     },
        --     {
        --       {
        --         framework = "xunit",
        --         id = "./tests/xunit/specs/custom_attribute.cs::XUnitSamples::CosmosConnectorTest",
        --         is_class = true,
        --         name = "CosmosConnectorTest",
        --         path = "./tests/xunit/specs/custom_attribute.cs",
        --         range = { 6, 0, 15, 1 },
        --         type = "namespace",
        --       },
        --       {
        --         {
        --           display_name = "Custom attribute works ok",
        --           framework = "xunit",
        --           id = "./tests/xunit/specs/custom_attribute.cs::XUnitSamples::CosmosConnectorTest::Custom_Attribute_Tests",
        --           is_class = false,
        --           name = "Custom_Attribute_Tests",
        --           path = "./tests/xunit/specs/custom_attribute.cs",
        --           range = { 9, 4, 14, 5 },
        --           type = "test",
        --         },
        --       },
        --     },
        --   },
        -- }
      end

      assert.same(positions, get_expected_output(spec_file, spec_file_name))
    end
  )
end)
