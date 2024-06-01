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
              framework = "nunit",
              id = file_path .. "::Tests",
              is_class = true,
              name = "Tests",
              path = file_path,
              range = { 4, 0, 24, 1 },
              type = "namespace",
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::Tests::DivideTest",
                is_class = false,
                name = "DivideTest",
                path = file_path,
                range = { 12, 4, 16, 5 },
                type = "test",
              },
            },
          },
        }

        -- 01-06-2024: c_sharp treesitter parser changes mean file scoped namespaces don't include content of file as their range anymore
        -- - Other spec files have been modified accoridingly until parse has been fixed
        -- return {
        --   {
        --     id = file_path,
        --     name = file_name,
        --     path = file_path,
        --     range = { 0, 0, 25, 0 },
        --     type = "file",
        --   },
        --   {
        --     {
        --       framework = "nunit",
        --       id = file_path .. "::NUnitSamples",
        --       is_class = false,
        --       name = "NUnitSamples",
        --       path = file_path,
        --       range = { 2, 0, 24, 1 },
        --       type = "namespace",
        --     },
        --     {
        --       {
        --         framework = "nunit",
        --         id = file_path .. "::NUnitSamples::Tests",
        --         is_class = true,
        --         name = "Tests",
        --         path = file_path,
        --         range = { 4, 0, 24, 1 },
        --         type = "namespace",
        --       },
        --       {
        --         {
        --           framework = "nunit",
        --           id = file_path .. "::NUnitSamples::Tests::DivideTest",
        --           is_class = false,
        --           name = "DivideTest",
        --           path = file_path,
        --           range = { 12, 4, 16, 5 },
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

  async.it("should discover Specflow Generate tests", function()
    local spec_file = "./tests/nunit/specs/specflow.cs"
    local spec_file_name = "specflow.cs"
    local positions = plugin.discover_positions(spec_file):to_list()

    local function get_expected_output(file_path, file_name)
      return {
        {
          id = file_path,
          name = file_name,
          path = file_path,
          range = { 0, 0, 108, 0 },
          type = "file",
        },
        {
          {
            framework = "nunit",
            id = file_path .. "::NUnitSamples",
            is_class = false,
            name = "NUnitSamples",
            path = file_path,
            range = { 12, 0, 105, 1 },
            type = "namespace",
          },
          {
            {
              framework = "nunit",
              id = file_path .. "::NUnitSamples::DummyTestFeature",
              is_class = true,
              name = "DummyTestFeature",
              path = file_path,
              range = { 19, 4, 104, 5 },
              type = "namespace",
            },
            {
              {
                framework = "nunit",
                id = file_path .. "::NUnitSamples::DummyTestFeature::DummyScenario",
                is_class = false,
                name = "DummyScenario",
                path = file_path,
                range = { 75, 8, 103, 9 },
                type = "test",
              },
            },
          },
        },
      }
    end

    assert.same(positions, get_expected_output(spec_file, spec_file_name))
  end)
end)
