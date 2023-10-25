local async = require("nio").tests

describe("is_test_file", function()
  require("neotest").setup({
    adapters = {
      require("neotest-dotnet")({
        discovery_root = "solution",
      }),
    },
  })

  async.it("should return true for NUnit Specflow Generated File", function()
    local plugin = require("neotest-dotnet")
    local dir = "./tests/nunit/specs/specflow.cs"

    local result = plugin.is_test_file(dir)

    assert.equal(true, result)
  end)
end)
