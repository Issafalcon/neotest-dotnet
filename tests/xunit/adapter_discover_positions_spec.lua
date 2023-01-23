local async = require("plenary.async.tests")
local plugin = require("neotest-dotnet")
local Tree = require("neotest.types").Tree
A = function(...)
  print(vim.inspect(...))
end

describe("discover_positions", function()
  async.it("should discover tests with inline parameters", function()
    local positions = plugin.discover_positions("./tests/xunit/specs/basic_tests.cs"):to_list()

    local expected_output = {
      {
        id = "./tests/xunit/specs/basic_tests.cs",
        name = "basic_tests.cs",
        path = "./tests/xunit/specs/basic_tests.cs",
        range = { 0, 0, 18, 0 },
        type = "file",
      },
      {
        {
          id = "./tests/xunit/specs/basic_tests.cs::xunit.testproj1",
          name = "xunit.testproj1",
          path = "./tests/xunit/specs/basic_tests.cs",
          range = { 0, 0, 17, 1 },
          type = "namespace",
        },
        {
          {
            id = "./tests/xunit/specs/basic_tests.cs::xunit.testproj1::UnitTest1",
            name = "UnitTest1",
            path = "./tests/xunit/specs/basic_tests.cs",
            range = { 2, 0, 17, 1 },
            type = "namespace",
          },
          {
            {
              id = "./tests/xunit/specs/basic_tests.cs::xunit.testproj1::UnitTest1::Test1",
              name = "Test1",
              path = "./tests/xunit/specs/basic_tests.cs",
              range = { 4, 1, 8, 2 },
              type = "test",
            },
          },
          {
            {
              id = "./tests/xunit/specs/basic_tests.cs::xunit.testproj1::UnitTest1::Test2",
              name = "Test2",
              path = "./tests/xunit/specs/basic_tests.cs",
              range = { 10, 1, 16, 2 },
              type = "test",
            },
            {
              {
                id = "./tests/xunit/specs/basic_tests.cs::xunit.testproj1::UnitTest1::Test2(a: 1)",
                name = "Test2(a: 1)",
                path = "./tests/xunit/specs/basic_tests.cs",
                range = { 11, 12, 11, 15 },
                type = "test",
              },
            },
            {
              {
                id = "./tests/xunit/specs/basic_tests.cs::xunit.testproj1::UnitTest1::Test2(a: 2)",
                name = "Test2(a: 2)",
                path = "./tests/xunit/specs/basic_tests.cs",
                range = { 12, 12, 12, 15 },
                type = "test",
              },
            },
          },
        },
      },
    }

    assert.same(positions, expected_output)
  end)
end)
