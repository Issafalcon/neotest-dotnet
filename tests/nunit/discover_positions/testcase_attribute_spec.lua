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
    "should discover tests with TestCase attribute and create nested parameterized tests",
    function()
      local file_name = "testcase.cs"
      local file_path = "./tests/nunit/specs/testcase.cs"
      local positions = plugin.discover_positions(file_path):to_list()

      local expected_output = {
        {
          id = file_path,
          name = file_name,
          path = file_path,
          range = { 0, 0, 18, 0 },
          type = "file",
        },
        {
          {
            framework = "nunit",
            id = file_path .. "::Tests",
            is_class = true,
            name = "Tests",
            path = file_path,
            range = { 4, 0, 17, 1 },
            type = "namespace",
          },
          {
            {
              framework = "nunit",
              id = file_path .. "::Tests::DivideTest",
              is_class = false,
              name = "DivideTest",
              path = file_path,
              range = { 10, 4, 16, 5 },
              type = "test",
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::Tests::DivideTest(12, 3, 4)",
                is_class = false,
                name = "DivideTest(12, 3, 4)",
                path = file_path,
                range = { 10, 13, 10, 23 },
                type = "test",
              },
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::Tests::DivideTest(12, 2, 6)",
                is_class = false,
                name = "DivideTest(12, 2, 6)",
                path = file_path,
                range = { 11, 13, 11, 23 },
                type = "test",
              },
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::Tests::DivideTest(12, 4, 3)",
                is_class = false,
                name = "DivideTest(12, 4, 3)",
                path = file_path,
                range = { 12, 13, 12, 23 },
                type = "test",
              },
            },
          },
        },
      }

      assert.same(expected_output, positions)
    end
  )

  async.it(
    "should discover tests with TestCase attribute and create nested parameterized tests if there is a redundant TestAttribute",
    function()
      local file_name = "test_with_testcase.cs"
      local file_path = "./tests/nunit/specs/" .. file_name
      local positions = plugin.discover_positions(file_path):to_list()

      local expected_output = {
        {
          id = file_path,
          name = file_name,
          path = file_path,
          range = { 0, 0, 19, 0 },
          type = "file",
        },
        {
          {
            framework = "nunit",
            id = file_path .. "::Tests",
            is_class = true,
            name = "Tests",
            path = file_path,
            range = { 4, 0, 18, 1 },
            type = "namespace",
          },
          {
            {
              framework = "nunit",
              id = file_path .. "::Tests::DivideTest",
              is_class = false,
              name = "DivideTest",
              path = file_path,
              range = { 10, 4, 17, 5 },
              type = "test",
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::Tests::DivideTest(12, 3, 4)",
                is_class = false,
                name = "DivideTest(12, 3, 4)",
                path = file_path,
                range = { 11, 13, 11, 23 },
                type = "test",
              },
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::Tests::DivideTest(12, 2, 6)",
                is_class = false,
                name = "DivideTest(12, 2, 6)",
                path = file_path,
                range = { 12, 13, 12, 23 },
                type = "test",
              },
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::Tests::DivideTest(12, 4, 3)",
                is_class = false,
                name = "DivideTest(12, 4, 3)",
                path = file_path,
                range = { 13, 13, 13, 23 },
                type = "test",
              },
            },
          },
        },
      }

      assert.same(expected_output[2][2], positions[2][2])
    end
  )
end)
