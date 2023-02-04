local async = require("plenary.async.tests")
local mock = require("luassert.mock")

describe("build_test_fqn windows_os", function()
  local BuildSpecUtils = require("neotest-dotnet.build-spec-utils")
  local mock = require("luassert.mock")
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
end)
