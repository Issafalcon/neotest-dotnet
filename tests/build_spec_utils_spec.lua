local async = require("plenary.async.tests")
local mock = require("luassert.mock")
local stub = require("luassert.stub")
local lib = require("neotest.lib")

describe("build_test_fqn windows_os", function()
  local BuildSpecUtils = require("neotest-dotnet.build-spec-utils")
  local fn_mock = mock(vim.fn, true)
  fn_mock.has.returns(true)

  it("should return the fully qualified name of the test", function()
    local fqn = BuildSpecUtils.build_test_fqn("C:\\path\\to\\file.cs::namespace::class::method")
    assert.are.equals(fqn, "namespace.class.method")
  end)

  it("should return the fully qualified name of the test when the test has parameters", function()
    local fqn =
      BuildSpecUtils.build_test_fqn("C:\\path\\to\\file.cs::namespace::class::method(a: 1)")
    assert.are.equals(fqn, "namespace.class.method")
  end)

  it(
    "should return the fully qualified name of the test when the test has multiple parameters",
    function()
      local fqn =
        BuildSpecUtils.build_test_fqn("C:\\path\\to\\file.cs::namespace::class::method(a: 1, b: 2)")
      assert.are.equals(fqn, "namespace.class.method")
    end
  )
  mock.revert(fn_mock)
end)

describe("build_test_fqn linux", function()
  local BuildSpecUtils = require("neotest-dotnet.build-spec-utils")
  local mock = require("luassert.mock")
  local fn_mock = mock(vim.fn, true)
  fn_mock.has.returns(false)

  it("should return the fully qualified name of the test", function()
    local fqn = BuildSpecUtils.build_test_fqn("/path/to/file.cs::namespace::class::method")
    assert.are.equals(fqn, "namespace.class.method")
  end)

  it("should return the fully qualified name of the test when the test has parameters", function()
    local fqn = BuildSpecUtils.build_test_fqn("/path/to/file.cs::namespace::class::method(a: 1)")
    assert.are.equals(fqn, "namespace.class.method")
  end)

  it(
    "should return the fully qualified name of the test when the test has multiple parameters",
    function()
      local fqn =
        BuildSpecUtils.build_test_fqn("/path/to/file.cs::namespace::class::method(a: 1, b: 2)")
      assert.are.equals(fqn, "namespace.class.method")
    end
  )
  mock.revert(fn_mock)
end)

describe("create_specs", function()
  local BuildSpecUtils = require("neotest-dotnet.build-spec-utils")
  local test_result_path = "/tmp/test_result.trx"
  -- local lib = require("neotest.lib")
  -- local lib_mock = mock(lib.files, true)
  -- fn_mock.tempname.returns(test_result_path)
  -- lib_mock.files.match_root_pattern.returns(function(path)
  --   return "test"
  -- end)
  before_each(function()
    stub(lib.files, "match_root_pattern", function(_)
      return function(_)
        return "test"
      end
    end)
  end)

  it("should return correct spec when position is 'file' type", function()
    local expected_specs = {
      {
        command = 'dotnet test /home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj2  --results-directory /tmp/nvim.issafalcon/794d7y --logger "trx;logfilename=0.trx"',
        context = {
          file = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj2/UnitTest1.cs",
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj2/UnitTest1.cs",
          results_path = test_result_path,
        },
      },
    }

    -- TODO: Get this tree using the 'from_list' function on the Tree obj
    local tree = {
      "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj2/UnitTest1.cs",
      adapter = "neotest-dotnet:/home/issafalcon/repos/neotest-dotnet-tests",
      strategy = "integrated",
      tree = {
        _data = {
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj2/UnitTest1.cs",
          name = "UnitTest1.cs",
          path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj2/UnitTest1.cs",
          range = { 0, 0, 27, 0 },
          type = "file",
        },
      },
    }

    local result = BuildSpecUtils.create_specs(tree)

    assert.equal(#expected_specs, #result)
  end)
end)
