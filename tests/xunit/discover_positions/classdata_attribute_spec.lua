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
      require("neotest-dotnet"),
    },
  })

  before_each(function()
    stub(DotnetUtils, "get_test_full_names", function()
      return {
        is_complete = true,
        result = function()
          return {
            output = {
              "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: 1, v2: 2)",
              "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -4, v2: 6)",
              "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -2, v2: 2)",
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
    "should discover tests with classdata attribute without creating nested parameterized tests",
    function()
      local spec_file = "./tests/xunit/specs/classdata.cs"
      local spec_file_name = "classdata.cs"
      local positions = plugin.discover_positions(spec_file):to_list()

      local function get_expected_output(file_path, file_name)
        return {
          {
            id = "./tests/xunit/specs/classdata.cs",
            name = "classdata.cs",
            path = "./tests/xunit/specs/classdata.cs",
            range = { 0, 0, 28, 0 },
            type = "file",
          },
          {
            {
              framework = "xunit",
              id = "./tests/xunit/specs/classdata.cs::ClassDataTests",
              is_class = true,
              name = "ClassDataTests",
              path = "./tests/xunit/specs/classdata.cs",
              range = { 6, 0, 15, 1 },
              type = "namespace",
            },
            {
              {
                framework = "xunit",
                id = "./tests/xunit/specs/classdata.cs::ClassDataTests::Theory_With_Class_Data_Test",
                is_class = false,
                name = "Theory_With_Class_Data_Test",
                path = "./tests/xunit/specs/classdata.cs",
                range = { 8, 1, 14, 2 },
                running_id = "./tests/xunit/specs/classdata.cs::ClassDataTests::Theory_With_Class_Data_Test",
                type = "test",
              },
              {
                {
                  framework = "xunit",
                  id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test(v1: 1, v2: 2)",
                  is_class = false,
                  name = "Theory_With_Class_Data_Test(v1: 1, v2: 2)",
                  path = "./tests/xunit/specs/classdata.cs",
                  range = { 9, 1, 9, 2 },
                  running_id = "./tests/xunit/specs/classdata.cs::ClassDataTests::Theory_With_Class_Data_Test",
                  type = "test",
                },
              },
              {
                {
                  framework = "xunit",
                  id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test(v1: -4, v2: 6)",
                  is_class = false,
                  name = "Theory_With_Class_Data_Test(v1: -4, v2: 6)",
                  path = "./tests/xunit/specs/classdata.cs",
                  range = { 10, 1, 10, 2 },
                  running_id = "./tests/xunit/specs/classdata.cs::ClassDataTests::Theory_With_Class_Data_Test",
                  type = "test",
                },
              },
              {
                {
                  framework = "xunit",
                  id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test(v1: -2, v2: 2)",
                  is_class = false,
                  name = "Theory_With_Class_Data_Test(v1: -2, v2: 2)",
                  path = "./tests/xunit/specs/classdata.cs",
                  range = { 11, 1, 11, 2 },
                  running_id = "./tests/xunit/specs/classdata.cs::ClassDataTests::Theory_With_Class_Data_Test",
                  type = "test",
                },
              },
            },
          },
        }
        -- return {
        --   {
        --     id = "./tests/xunit/specs/classdata.cs",
        --     name = "classdata.cs",
        --     path = "./tests/xunit/specs/classdata.cs",
        --     range = { 0, 0, 28, 0 },
        --     type = "file",
        --   },
        --   {
        --     {
        --       framework = "xunit",
        --       id = "./tests/xunit/specs/classdata.cs::XUnitSamples",
        --       is_class = false,
        --       name = "XUnitSamples",
        --       path = "./tests/xunit/specs/classdata.cs",
        --       range = { 4, 0, 27, 1 },
        --       type = "namespace",
        --     },
        --     {
        --       {
        --         framework = "xunit",
        --         id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests",
        --         is_class = true,
        --         name = "ClassDataTests",
        --         path = "./tests/xunit/specs/classdata.cs",
        --         range = { 6, 0, 15, 1 },
        --         type = "namespace",
        --       },
        --       {
        --         {
        --           framework = "xunit",
        --           id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test",
        --           is_class = false,
        --           name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test",
        --           path = "./tests/xunit/specs/classdata.cs",
        --           range = { 8, 1, 14, 2 },
        --           running_id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test",
        --           type = "test",
        --         },
        --         {
        --           {
        --             framework = "xunit",
        --             id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test(v1: 1, v2: 2)",
        --             is_class = false,
        --             name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: 1, v2: 2)",
        --             path = "./tests/xunit/specs/classdata.cs",
        --             range = { 9, 1, 9, 2 },
        --             running_id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test",
        --             type = "test",
        --           },
        --         },
        --         {
        --           {
        --             framework = "xunit",
        --             id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test(v1: -4, v2: 6)",
        --             is_class = false,
        --             name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -4, v2: 6)",
        --             path = "./tests/xunit/specs/classdata.cs",
        --             range = { 10, 1, 10, 2 },
        --             running_id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test",
        --             type = "test",
        --           },
        --         },
        --         {
        --           {
        --             framework = "xunit",
        --             id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test(v1: -2, v2: 2)",
        --             is_class = false,
        --             name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -2, v2: 2)",
        --             path = "./tests/xunit/specs/classdata.cs",
        --             range = { 11, 1, 11, 2 },
        --             running_id = "./tests/xunit/specs/classdata.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test",
        --             type = "test",
        --           },
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
