local async = require("nio").tests

describe("root when using solution option", function()
  require("neotest").setup({
    adapters = {
      require("neotest-dotnet")({
        discovery_root = "solution",
      }),
    },
  })

  async.it("should return .sln dir when it exists and path contains it", function()
    local plugin = require("neotest-dotnet")
    local dir = "./tests/solution_dir"
    local root = plugin.root(dir)

    assert.equal(dir, root)
  end)

  async.it("should return nil when neither path nor parents contain .sln file", function()
    local plugin = require("neotest-dotnet")
    local dir = "./tests/project_dir"
    local root = plugin.root(dir)

    assert.equal(nil, root)
  end)

  async.it("should return .sln dir when parent dir contains .sln file", function()
    local plugin = require("neotest-dotnet")
    local dir = "./tests/solution_dir/project1/tests"
    local parent_sln_dir = "/tests/solution_dir"
    local root = plugin.root(dir)

    -- Check the end of the root matches the test dir as the function
    -- in neotest will use the fully qualified path (which will vary)
    assert.is.True(string.find(root, parent_sln_dir .. "$") ~= nil)
  end)
end)

describe("root when using project option", function()
  require("neotest").setup({
    adapters = {
      require("neotest-dotnet")({
        discovery_root = "project",
      }),
    },
  })

  async.it("should return .csproj dir when it exists and path contains it", function()
    local plugin = require("neotest-dotnet")
    local dir = "./tests/project_dir"
    local root = plugin.root(dir)

    assert.equal(dir, root)
  end)

  async.it("should return nil when neither path nor parents contain .csproj file", function()
    local plugin = require("neotest-dotnet")
    local dir = "./tests/solution_dir"
    local root = plugin.root(dir)

    assert.equal(nil, root)
  end)

  async.it("should return .csproj dir when parent dir contains .csproj file", function()
    local plugin = require("neotest-dotnet")
    local dir = "./tests/project_dir/tests"
    local parent_proj_dir = "/tests/project_dir"
    local root = plugin.root(dir)

    -- Check the end of the root matches the test dir as the function
    -- in neotest will use the fully qualified path (which will vary)
    assert.is.True(string.find(root, parent_proj_dir .. "$") ~= nil)
  end)
end)
