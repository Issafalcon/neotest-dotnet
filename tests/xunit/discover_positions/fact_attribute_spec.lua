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
              "XUnitSamples.UnitTest1.Test1",
              "XUnitSamples.UnitTest1+NestedClass.Test1",
              "XUnitSamples.UnitTest1+NestedClass.Test2",
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

  async.it("should discover Fact tests when not the only attribute", function()
    local spec_file = "./tests/xunit/specs/fact_and_trait.cs"
    local spec_file_name = "fact_and_trait.cs"
    local positions = plugin.discover_positions(spec_file):to_list()

    local expected_positions = {
      {
        id = spec_file,
        name = spec_file_name,
        path = spec_file,
        range = { 0, 0, 11, 0 },
        type = "file",
      },
      {
        {
          framework = "xunit",
          id = spec_file .. "::UnitTest1",
          is_class = true,
          name = "UnitTest1",
          path = spec_file,
          range = { 2, 0, 10, 1 },
          type = "namespace",
        },
        {
          {
            framework = "xunit",
            id = spec_file .. "::UnitTest1::Test1",
            is_class = false,
            name = "Test1",
            path = spec_file,
            range = { 4, 1, 9, 2 },
            running_id = "./tests/xunit/specs/fact_and_trait.cs::UnitTest1::Test1",
            type = "test",
          },
        },
      },
    }
    -- local expected_positions = {
    --   {
    --     id = spec_file,
    --     name = spec_file_name,
    --     path = spec_file,
    --     range = { 0, 0, 11, 0 },
    --     type = "file",
    --   },
    --   {
    --     {
    --       framework = "xunit",
    --       id = spec_file .. "::xunit.testproj1",
    --       is_class = false,
    --       name = "xunit.testproj1",
    --       path = spec_file,
    --       range = { 0, 0, 10, 1 },
    --       type = "namespace",
    --     },
    --     {
    --       {
    --         framework = "xunit",
    --         id = spec_file .. "::xunit.testproj1::UnitTest1",
    --         is_class = true,
    --         name = "UnitTest1",
    --         path = spec_file,
    --         range = { 2, 0, 10, 1 },
    --         type = "namespace",
    --       },
    --       {
    --         {
    --           framework = "xunit",
    --           id = spec_file .. "::xunit.testproj1::UnitTest1::Test1",
    --           is_class = false,
    --           name = "Test1",
    --           path = spec_file,
    --           range = { 4, 1, 9, 2 },
    --           type = "test",
    --         },
    --       },
    --     },
    --   },
    -- }

    assert.same(positions, expected_positions)
  end)

  async.it("should discover single tests in sub-class", function()
    local spec_file = "./tests/xunit/specs/nested_class.cs"
    local spec_file_name = "nested_class.cs"
    local positions = plugin.discover_positions(spec_file):to_list()

    local expected_positions = {
      {
        id = spec_file,
        name = spec_file_name,
        path = spec_file,
        range = { 0, 0, 27, 0 },
        type = "file",
      },
      {
        {
          framework = "xunit",
          id = spec_file .. "::UnitTest1",
          is_class = true,
          name = "UnitTest1",
          path = spec_file,
          range = { 4, 0, 26, 1 },
          type = "namespace",
        },
        {
          {
            framework = "xunit",
            id = spec_file .. "::UnitTest1::Test1",
            is_class = false,
            name = "Test1",
            path = spec_file,
            range = { 6, 1, 10, 2 },
            running_id = "./tests/xunit/specs/nested_class.cs::UnitTest1::Test1",
            type = "test",
          },
        },
        {
          {
            framework = "xunit",
            id = spec_file .. "::UnitTest1+NestedClass",
            is_class = true,
            name = "NestedClass",
            path = spec_file,
            range = { 12, 1, 25, 2 },
            type = "namespace",
          },
          {
            {
              framework = "xunit",
              id = spec_file .. "::UnitTest1+NestedClass::Test1",
              is_class = false,
              name = "Test1",
              path = spec_file,
              range = { 14, 2, 18, 3 },
              running_id = "./tests/xunit/specs/nested_class.cs::UnitTest1+NestedClass::Test1",
              type = "test",
            },
          },
          {
            {
              framework = "xunit",
              id = spec_file .. "::UnitTest1+NestedClass::Test2",
              is_class = false,
              name = "Test2",
              path = spec_file,
              range = { 20, 2, 24, 3 },
              running_id = "./tests/xunit/specs/nested_class.cs::UnitTest1+NestedClass::Test2",
              type = "test",
            },
          },
        },
      },
    }
    -- local expected_positions = {
    --   {
    --     id = spec_file,
    --     name = spec_file_name,
    --     path = spec_file,
    --     range = { 0, 0, 27, 0 },
    --     type = "file",
    --   },
    --   {
    --     {
    --       framework = "xunit",
    --       id = spec_file .. "::XUnitSamples",
    --       is_class = false,
    --       name = "XUnitSamples",
    --       path = spec_file,
    --       range = { 2, 0, 26, 1 },
    --       type = "namespace",
    --     },
    --     {
    --       {
    --         framework = "xunit",
    --         id = spec_file .. "::XUnitSamples::UnitTest1",
    --         is_class = true,
    --         name = "UnitTest1",
    --         path = spec_file,
    --         range = { 4, 0, 26, 1 },
    --         type = "namespace",
    --       },
    --       {
    --         {
    --           framework = "xunit",
    --           id = spec_file .. "::XUnitSamples::UnitTest1::Test1",
    --           is_class = false,
    --           name = "XUnitSamples.UnitTest1.Test1",
    --           path = spec_file,
    --           range = { 6, 1, 10, 2 },
    --           running_id = "./tests/xunit/specs/nested_class.cs::XUnitSamples::UnitTest1::Test1",
    --           type = "test",
    --         },
    --       },
    --       {
    --         {
    --           framework = "xunit",
    --           id = spec_file .. "::XUnitSamples::UnitTest1+NestedClass",
    --           is_class = true,
    --           name = "NestedClass",
    --           path = spec_file,
    --           range = { 12, 1, 25, 2 },
    --           type = "namespace",
    --         },
    --         {
    --           {
    --             framework = "xunit",
    --             id = spec_file .. "::XUnitSamples::UnitTest1+NestedClass::Test1",
    --             is_class = false,
    --             name = "XUnitSamples.UnitTest1+NestedClass.Test1",
    --             path = spec_file,
    --             range = { 14, 2, 18, 3 },
    --             running_id = "./tests/xunit/specs/nested_class.cs::XUnitSamples::UnitTest1+NestedClass::Test1",
    --             type = "test",
    --           },
    --         },
    --         {
    --           {
    --             framework = "xunit",
    --             id = spec_file .. "::XUnitSamples::UnitTest1+NestedClass::Test2",
    --             is_class = false,
    --             name = "XUnitSamples.UnitTest1+NestedClass.Test2",
    --             path = spec_file,
    --             range = { 20, 2, 24, 3 },
    --             running_id = "./tests/xunit/specs/nested_class.cs::XUnitSamples::UnitTest1+NestedClass::Test2",
    --             type = "test",
    --           },
    --         },
    --       },
    --     },
    --   },
    -- }

    assert.same(positions, expected_positions)
  end)
end)
