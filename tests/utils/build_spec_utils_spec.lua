local async = require("nio").tests
local mock = require("luassert.mock")
local stub = require("luassert.stub")
local lib = require("neotest.lib")
local Tree = require("neotest.types").Tree

describe("build_test_fqn windows_os", function()
  local BuildSpecUtils = require("neotest-dotnet.utils.build-spec-utils")
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
  local BuildSpecUtils = require("neotest-dotnet.utils.build-spec-utils")
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
  local BuildSpecUtils = require("neotest-dotnet.utils.build-spec-utils")
  local test_result_path = "/tmp/output/test_result"
  local test_root_path = "/dummy/path/to/proj"

  local function assert_spec_matches(expected, actual)
    assert.equal(expected.command, actual.command)
    assert.equal(expected.context.file, actual.context.file)
    assert.equal(expected.context.id, actual.context.id)
    assert.equal(expected.context.results_path, actual.context.results_path)
  end

  before_each(function()
    -- fn_mock.tempname.returns(test_result_path)

    stub(vim.fn, "tempname", function()
      return test_result_path
    end)
    stub(lib.files, "match_root_pattern", function(_)
      return function(_)
        return test_root_path
      end
    end)
  end)

  after_each(function()
    lib.files.match_root_pattern:revert()
    vim.fn.tempname:revert()
  end)

  it("should return correct spec when position is 'file' type", function()
    local expected_specs = {
      {
        command = "dotnet test "
          .. test_root_path
          .. ' --filter "Name~UnitTest1" --results-directory /tmp/output --logger "trx;logfilename=test_result.trx"',
        context = {
          file = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
          results_path = test_result_path .. ".trx",
        },
      },
    }

    local tree = Tree.from_list({
      {
        id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
        name = "UnitTest1.cs",
        path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
        range = { 0, 0, 19, 0 },
        type = "file",
      },
      {
        {
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1",
          name = "xunit.testproj1",
          path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
          range = { 0, 0, 18, 1 },
          type = "namespace",
        },
        {
          {
            id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1::UnitTest1",
            name = "UnitTest1",
            path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
            range = { 2, 0, 18, 1 },
            type = "namespace",
            is_class = true,
          },
          {
            {
              id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1::UnitTest1::Test1",
              name = "Test1",
              path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
              range = { 4, 1, 8, 2 },
              type = "test",
            },
          },
        },
      },
    }, function(pos)
      return pos.id
    end)

    local result = BuildSpecUtils.create_specs(tree)

    assert.equal(#expected_specs, #result)
    assert_spec_matches(expected_specs[1], result[1])
  end)

  async.it("should return the correct specs when the position is 'namespace' type", function()
    local expected_specs = {
      {
        command = "dotnet test "
          .. test_root_path
          .. ' --filter FullyQualifiedName~"xunit.testproj1"'
          .. ' --results-directory /tmp/output --logger "trx;logfilename=test_result.trx"',
        context = {
          file = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1",
          results_path = test_result_path .. ".trx",
        },
      },
    }

    local tree = Tree.from_list({
      {
        id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1",
        name = "xunit.testproj1",
        path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
        range = { 0, 0, 18, 1 },
        type = "namespace",
      },
      {
        {
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1::UnitTest1",
          name = "UnitTest1",
          path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
          range = { 2, 0, 18, 1 },
          type = "namespace",
        },
        {
          {
            id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1::UnitTest1::Test1",
            name = "Test1",
            path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
            range = { 4, 1, 8, 2 },
            type = "test",
          },
        },
      },
    }, function(pos)
      return pos.id
    end)

    local result = BuildSpecUtils.create_specs(tree)

    assert.equal(#expected_specs, #result)
    assert_spec_matches(expected_specs[1], result[1])
  end)

  async.it("should return the correct specs when the position is 'test' type", function()
    local expected_specs = {
      {
        command = "dotnet test "
          .. test_root_path
          .. ' --filter FullyQualifiedName~"xunit.testproj1.UnitTest1.Test1"'
          .. ' --results-directory /tmp/output --logger "trx;logfilename=test_result.trx"',
        context = {
          file = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1::UnitTest1::Test1",
          results_path = test_result_path .. ".trx",
        },
      },
    }

    local tree = Tree.from_list({
      {
        id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs::xunit.testproj1::UnitTest1::Test1",
        name = "Test1",
        path = "/home/issafalcon/repos/neotest-dotnet-tests/xunit/testproj1/UnitTest1.cs",
        range = { 4, 1, 8, 2 },
        type = "test",
      },
    }, function(pos)
      return pos.id
    end)

    local result = BuildSpecUtils.create_specs(tree)

    assert.equal(#expected_specs, #result)
    assert_spec_matches(expected_specs[1], result[1])
  end)

  async.it(
    "should return the correct specs when the position is 'test' type and the test is in a nested namespace",
    function()
      local expected_specs = {
        {
          command = "dotnet test "
            .. test_root_path
            .. ' --filter FullyQualifiedName~"XUnitSamples.UnitTest1+NestedClass.Test1"'
            .. ' --results-directory /tmp/output --logger "trx;logfilename=test_result.trx"',
          context = {
            file = "./tests/xunit/specs/nested_class.cs",
            id = "./tests/xunit/specs/nested_class.cs::XUnitSamples::UnitTest1+NestedClass::Test1",
            results_path = test_result_path .. ".trx",
          },
        },
      }

      local tree = Tree.from_list({
        {
          id = "./tests/xunit/specs/nested_class.cs::XUnitSamples::UnitTest1+NestedClass::Test1",
          is_class = false,
          name = "Test1",
          path = "./tests/xunit/specs/nested_class.cs",
          range = { 14, 2, 18, 3 },
          type = "test",
        },
      }, function(pos)
        return pos.id
      end)

      local result = BuildSpecUtils.create_specs(tree)

      assert.equal(#expected_specs, #result)
      assert_spec_matches(expected_specs[1], result[1])
    end
  )

  -- Caters for situation where root directory contains a .sln file, and there are nested dirs with .csproj files in them
  async.it(
    "should return multiple specs when the position is 'dir' type and contains nested project roots",
    function()
      local solution_dir = vim.fn.expand("%:p:h") .. "/tests/solution_dir"
      local project1_dir = vim.fn.expand("%:p:h") .. "/tests/solution_dir/project1"
      local project2_dir = vim.fn.expand("%:p:h") .. "/tests/solution_dir/project2"

      local expected_specs = {
        {
          command = "dotnet test "
            .. project1_dir
            .. '  --results-directory /tmp/output --logger "trx;logfilename=test_result.trx"',
          context = {
            file = project1_dir,
            id = project1_dir,
            results_path = test_result_path .. ".trx",
          },
        },
        {
          command = "dotnet test "
            .. project2_dir
            .. '  --results-directory /tmp/output --logger "trx;logfilename=test_result.trx"',
          context = {
            file = project2_dir,
            id = project2_dir,
            results_path = test_result_path .. ".trx",
          },
        },
      }

      local tree = Tree.from_list({
        {
          id = "/home/issafalcon/repos/neotest-dotnet-tests/xunit",
          name = "xunit",
          path = solution_dir,
          type = "dir",
        },
        {
          {
            id = project1_dir,
            name = "testproj1",
            path = project1_dir,
            type = "dir",
          },
        },
        {
          {
            id = project2_dir,
            name = "testproj2",
            path = project2_dir,
            type = "dir",
          },
        },
      }, function(pos)
        return pos.id
      end)

      local result = BuildSpecUtils.create_specs(tree)

      assert.equal(#expected_specs, #result)
      assert_spec_matches(expected_specs[1], result[1])
      assert_spec_matches(expected_specs[2], result[2])
    end
  )

  async.it(
    "should return single spec when the position is 'dir' type and contains a single project root",
    function()
      local project1_dir = vim.fn.expand("%:p:h") .. "/tests/solution_dir/project1"

      local expected_specs = {
        {
          command = "dotnet test "
            .. project1_dir
            .. '  --results-directory /tmp/output --logger "trx;logfilename=test_result.trx"',
          context = {
            file = project1_dir,
            id = project1_dir,
            results_path = test_result_path .. ".trx",
          },
        },
      }

      local tree = Tree.from_list({
        {
          id = project1_dir,
          name = "testproj1",
          path = project1_dir,
          type = "dir",
        },
      }, function(pos)
        return pos.id
      end)

      local result = BuildSpecUtils.create_specs(tree)

      assert.equal(#expected_specs, #result)
      assert_spec_matches(expected_specs[1], result[1])
    end
  )
end)
