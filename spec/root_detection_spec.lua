describe("Test root detection", function()
  -- increase nio.test timeout
  vim.env.PLENARY_TEST_TIMEOUT = 20000
  -- add test_discovery script and treesitter parsers installed with luarocks
  vim.opt.runtimepath:append(vim.fn.getcwd())
  vim.opt.runtimepath:append(vim.fn.expand("~/.luarocks/lib/lua/5.1/"))

  local nio = require("nio")
  nio.tests.it("Detect .sln file as root", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"
    local root = plugin.root(dir)
    assert.are_equal(dir, root)
  end)
  nio.tests.it("Detect .sln file as root from project dir", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_solution"
    local root = plugin.root(dir .. "/src/FsharpTest")
    assert.are_equal(dir, root)
  end)
  nio.tests.it("Detect .fsproj file as root from project dir with no .sln file", function()
    local plugin = require("neotest-dotnet")
    local dir = vim.fn.getcwd() .. "/spec/samples/test_project"
    local root = plugin.root(dir)
    assert.are_equal(dir, root)
  end)
end)
