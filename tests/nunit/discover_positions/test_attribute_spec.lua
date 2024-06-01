local async = require("nio").tests
local plugin = require("neotest-dotnet")
local Tree = require("neotest.types").Tree

A = function(...)
  print(vim.inspect(...))
end

describe("discover_positions", function()
  require("neotest").setup({
    adapters = {
      require("neotest-dotnet"),
    },
  })

  async.it("should discover non parameterized tests without TestFixture", function()
    local spec_file = "./tests/nunit/specs/test_simple.cs"
    local spec_file_name = "test_simple.cs"
    local positions = plugin.discover_positions(spec_file):to_list()

    local expected_positions = {
      {
        id = spec_file,
        name = spec_file_name,
        path = spec_file,
        range = { 0, 0, 17, 0 },
        type = "file",
      },
      {
        {
          framework = "nunit",
          id = spec_file .. "::SingleTests",
          is_class = true,
          name = "SingleTests",
          path = spec_file,
          range = { 4, 0, 16, 1 },
          type = "namespace",
        },
        {
          {
            framework = "nunit",
            id = spec_file .. "::SingleTests::Test1",
            is_class = false,
            name = "Test1",
            path = spec_file,
            range = { 11, 1, 15, 2 },
            type = "test",
          },
        },
      },
    }

    assert.same(positions, expected_positions)
  end)

  -- TODO:
  -- 1. Write tests for non-inline parameterized tests
  -- 2. Write tests for nested namespaces
  -- 3. Write tests for nested classes
end)
