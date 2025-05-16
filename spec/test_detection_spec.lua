describe("Test test detection", function()
  -- increase nio.test timeout
  vim.env.PLENARY_TEST_TIMEOUT = 20000
  -- add test_discovery script and treesitter parsers installed with luarocks
  vim.opt.runtimepath:append(vim.fn.getcwd())
  vim.opt.runtimepath:append(vim.fn.expand("~/.luarocks/lib/lua/5.1/"))

  local nio = require("nio")

  require("neotest").setup({
    adapters = { require("neotest-dotnet") },
    log_level = 0,
  })

  nio.tests.it("detect tests in fsharp file", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"
    local test_file = dir .. "/src/FsharpTest/Tests.fs"
    local positions = plugin.discover_positions(test_file)

    local tests = {}

    for _, position in positions:iter() do
      if position.type == "test" then
        tests[#tests + 1] = position.name
      end
    end

    local expected_tests = {
      "My test",
      "My test 2",
      "My test 3",
      "My slow test",
      "Pass cool test parametrized function<Int32, Int32>(x: 11, _y: 22, _z: 33)",
      "Pass cool test parametrized function<Int32, Int32>(x: 10, _y: 20, _z: 30)",
      "Pass cool test",
      "Pass cool test parametrized<Int32, Int32>(x: 10, _y: 20, _z: 30)",
    }

    table.sort(expected_tests)
    table.sort(tests)

    assert.are_same(expected_tests, tests)
  end)

  nio.tests.it("detect tests in c_sharp file", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"
    local test_file = dir .. "/src/CSharpTest/UnitTest1.cs"
    local positions = plugin.discover_positions(test_file)

    local tests = {}

    for _, position in positions:iter() do
      if position.type == "test" then
        tests[#tests + 1] = position.name
      end
    end

    local expected_tests = {
      "Test1",
      "Name of test 2",
      "TheoryTest(startDate: 2019-01-01T00:00:01.0000000, endDate: 2020-01-01T00:00:01.0000000)",
      "TheoryTest(startDate: 2019-01-01T00:00:01.0000000, endDate: 2019-12-31T23:59:59.0000000)",
    }

    table.sort(expected_tests)
    table.sort(tests)

    assert.are_same(expected_tests, tests)
  end)

  nio.tests.it("filter non test directory", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"

    assert.is_false(plugin.filter_dir("bin", "/src/CSharpTest/bin", dir))
  end)

  nio.tests.it("not filter test directory", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"

    assert.is_truthy(plugin.filter_dir("CSharpTest", "/src/CSharpTest", dir))
  end)

  nio.tests.it("identify test file", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"

    local test_file = dir .. "/src/CSharpTest/UnitTest1.cs"

    assert.is_truthy(plugin.is_test_file(test_file))
  end)

  nio.tests.it("filter non-test file", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"

    local project_file = dir .. "/src/CSharpTest/CSharpTest.csproj"

    assert.is_false(plugin.is_test_file(project_file))
  end)
end)
