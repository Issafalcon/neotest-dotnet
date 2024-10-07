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
              "xunit.testproj1.UnitTest1.Test1",
              "xunit.testproj1.UnitTest1.Test2(a: 1)",
              "xunit.testproj1.UnitTest1.Test2(a: 2)",
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

  async.it("should discover tests with inline parameters", function()
    local spec_file = "./tests/xunit/specs/theory_and_fact_mixed.cs"
    local spec_file_name = "theory_and_fact_mixed.cs"
    local positions = plugin.discover_positions(spec_file):to_list()

    local function get_expected_output()
      -- return {
      --   {
      --     id = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --     name = "theory_and_fact_mixed.cs",
      --     path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --     range = { 0, 0, 18, 0 },
      --     type = "file",
      --   },
      --   {
      --     {
      --       framework = "xunit",
      --       id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1",
      --       is_class = false,
      --       name = "xunit.testproj1",
      --       path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --       range = { 0, 0, 17, 1 },
      --       type = "namespace",
      --     },
      --     {
      --       {
      --         framework = "xunit",
      --         id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1::UnitTest1",
      --         is_class = true,
      --         name = "UnitTest1",
      --         path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --         range = { 2, 0, 17, 1 },
      --         type = "namespace",
      --       },
      --       {
      --         {
      --           framework = "xunit",
      --           id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1::UnitTest1::Test1",
      --           is_class = false,
      --           name = "xunit.testproj1.UnitTest1.Test1",
      --           path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --           range = { 4, 1, 8, 2 },
      --           running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1::UnitTest1::Test1",
      --           type = "test",
      --         },
      --       },
      --       {
      --         {
      --           framework = "xunit",
      --           id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1::UnitTest1::Test2",
      --           is_class = false,
      --           name = "xunit.testproj1.UnitTest1.Test2",
      --           path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --           range = { 10, 1, 16, 2 },
      --           running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1::UnitTest1::Test2",
      --           type = "test",
      --         },
      --         {
      --           {
      --             framework = "xunit",
      --             id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit::testproj1::UnitTest1::Test2(a: 1)",
      --             is_class = false,
      --             name = "xunit.testproj1.UnitTest1.Test2(a: 1)",
      --             path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --             range = { 11, 1, 11, 2 },
      --             running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1::UnitTest1::Test2",
      --             type = "test",
      --           },
      --         },
      --         {
      --           {
      --             framework = "xunit",
      --             id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit::testproj1::UnitTest1::Test2(a: 2)",
      --             is_class = false,
      --             name = "xunit.testproj1.UnitTest1.Test2(a: 2)",
      --             path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
      --             range = { 12, 1, 12, 2 },
      --             running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit.testproj1::UnitTest1::Test2",
      --             type = "test",
      --           },
      --         },
      --       },
      --     },
      --   },
      -- }
      return {
        {
          id = "./tests/xunit/specs/theory_and_fact_mixed.cs",
          name = "theory_and_fact_mixed.cs",
          path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
          range = { 0, 0, 18, 0 },
          type = "file",
        },
        {
          {
            framework = "xunit",
            id = "./tests/xunit/specs/theory_and_fact_mixed.cs::UnitTest1",
            is_class = true,
            name = "UnitTest1",
            path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
            range = { 2, 0, 17, 1 },
            type = "namespace",
          },
          {
            {
              framework = "xunit",
              id = "./tests/xunit/specs/theory_and_fact_mixed.cs::UnitTest1::Test1",
              is_class = false,
              name = "Test1",
              path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
              range = { 4, 1, 8, 2 },
              running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::UnitTest1::Test1",
              type = "test",
            },
          },
          {
            {
              framework = "xunit",
              id = "./tests/xunit/specs/theory_and_fact_mixed.cs::UnitTest1::Test2",
              is_class = false,
              name = "Test2",
              path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
              range = { 10, 1, 16, 2 },
              running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::UnitTest1::Test2",
              type = "test",
            },
            {
              {
                framework = "xunit",
                id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit::testproj1::UnitTest1::Test2(a: 1)",
                is_class = false,
                name = "Test2(a: 1)",
                path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
                range = { 11, 1, 11, 2 },
                running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::UnitTest1::Test2",
                type = "test",
              },
            },
            {
              {
                framework = "xunit",
                id = "./tests/xunit/specs/theory_and_fact_mixed.cs::xunit::testproj1::UnitTest1::Test2(a: 2)",
                is_class = false,
                name = "Test2(a: 2)",
                path = "./tests/xunit/specs/theory_and_fact_mixed.cs",
                range = { 12, 1, 12, 2 },
                running_id = "./tests/xunit/specs/theory_and_fact_mixed.cs::UnitTest1::Test2",
                type = "test",
              },
            },
          },
        },
      }
    end

    assert.same(positions, get_expected_output())
  end)

  async.it("should discover tests in block scoped namespace", function()
    local spec_file = "./tests/xunit/specs/block_scoped_namespace.cs"
    local positions = plugin.discover_positions(spec_file):to_list()

    local expected_positions = {
      {
        id = "./tests/xunit/specs/block_scoped_namespace.cs",
        name = "block_scoped_namespace.cs",
        path = "./tests/xunit/specs/block_scoped_namespace.cs",
        range = { 0, 0, 11, 0 },
        type = "file",
      },
      {
        {
          framework = "xunit",
          id = "./tests/xunit/specs/block_scoped_namespace.cs::xunit.testproj1",
          is_class = false,
          name = "xunit.testproj1",
          path = "./tests/xunit/specs/block_scoped_namespace.cs",
          range = { 0, 0, 10, 1 },
          type = "namespace",
        },
        {
          {
            framework = "xunit",
            id = "./tests/xunit/specs/block_scoped_namespace.cs::xunit.testproj1::UnitTest1",
            is_class = true,
            name = "UnitTest1",
            path = "./tests/xunit/specs/block_scoped_namespace.cs",
            range = { 2, 1, 9, 2 },
            type = "namespace",
          },
          {
            {
              framework = "xunit",
              id = "./tests/xunit/specs/block_scoped_namespace.cs::xunit.testproj1::UnitTest1::Test1",
              is_class = false,
              name = "Test1",
              path = "./tests/xunit/specs/block_scoped_namespace.cs",
              range = { 4, 2, 8, 3 },
              running_id = "./tests/xunit/specs/block_scoped_namespace.cs::xunit.testproj1::UnitTest1::Test1",
              type = "test",
            },
          },
        },
      },
    }

    assert.same(positions, expected_positions)
  end)
end)
