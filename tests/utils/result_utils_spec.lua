local Tree = require("neotest.types").Tree
local trx_result_mocks = require("tests.utils.mock_data.trx_results_mocks")
local test_node_mocks = require("tests.utils.mock_data.test_node_mocks")
local neotest_node_tree_utils = require("neotest-dotnet.utils.neotest-node-tree-utils")

A = function(...)
  print(vim.inspect(...))
end

describe("create_intermediate_results xUnit", function()
  local ResultUtils = require("neotest-dotnet.utils.result-utils")

  it(
    "should create correct intermediate results from simple inlined parameterized tests",
    function()
      local expected_results = {
        {
          raw_output = "passed",
          status = "passed",
          test_name = "XUnitSamples.ParameterizedTests.Test1(value: 1)",
        },
        {
          error_info = "Assert.True() Failure\nExpected: True\nActual:   False\nat XUnitSamples.ParameterizedTests.Test1(Int32 value) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs:line 13",
          raw_output = "failed",
          status = "failed",
          test_name = "XUnitSamples.ParameterizedTests.Test1(value: 3)",
        },
        {
          raw_output = "passed",
          status = "passed",
          test_name = "XUnitSamples.ParameterizedTests.Test1(value: 2)",
        },
      }
      local actual_results = ResultUtils.create_intermediate_results(
        trx_result_mocks.xunit_parameterized_tests_simple.trx_results,
        trx_result_mocks.xunit_parameterized_tests_simple.trx_test_definitions
      )

      assert.are.same(expected_results, actual_results)
    end
  )

  it("should create correct intermediate results from simple ClassData tests", function()
    local expected_results = {
      {
        error_info = "Assert.True() Failure\nExpected: True\nActual:   False\nat XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(Int32 v1, Int32 v2) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ClassDataTests.cs:line 14",
        raw_output = "failed",
        status = "failed",
        test_name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -2, v2: 2)",
      },
      {
        raw_output = "passed",
        status = "passed",
        test_name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: 1, v2: 2)",
      },
      {
        error_info = "Assert.True() Failure\nExpected: True\nActual:   False\nat XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(Int32 v1, Int32 v2) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ClassDataTests.cs:line 14",
        raw_output = "failed",
        status = "failed",
        test_name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -4, v2: 6)",
      },
    }
    local actual_results = ResultUtils.create_intermediate_results(
      trx_result_mocks.xunit_classdata_tests_simple.trx_results,
      trx_result_mocks.xunit_classdata_tests_simple.trx_test_definitions
    )

    assert.are.same(expected_results, actual_results)
  end)
end)

describe("convert_intermediate_results xUnit", function()
  local ResultUtils = require("neotest-dotnet.utils.result-utils")

  it(
    "should correctly convert simple inline parameterized intermediate results to neotest-results",
    function()
      local test_tree = Tree.from_list(
        test_node_mocks.xunit_parameterized_tests_simple.node_list,
        function(pos)
          return pos.id
        end
      )

      local test_nodes = neotest_node_tree_utils.get_test_nodes_data(test_tree)

      local expected_results = {
        ["/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs::XUnitSamples::ParameterizedTests::Test1(value: 1)"] = {
          errors = {},
          short = "XUnitSamples.ParameterizedTests.Test1(value: 1):passed",
          status = "passed",
        },
        ["/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs::XUnitSamples::ParameterizedTests::Test1(value: 2)"] = {
          errors = {},
          short = "XUnitSamples.ParameterizedTests.Test1(value: 2):passed",
          status = "passed",
        },
        ["/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs::XUnitSamples::ParameterizedTests::Test1(value: 3)"] = {
          errors = {
            {
              message = "XUnitSamples.ParameterizedTests.Test1(value: 3): Assert.True() Failure\nExpected: True\nActual:   False\nat XUnitSamples.ParameterizedTests.Test1(Int32 value) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs:line 13",
            },
          },
          short = "XUnitSamples.ParameterizedTests.Test1(value: 3):failed",
          status = "failed",
        },
      }
      local actual_results = ResultUtils.convert_intermediate_results(
        test_node_mocks.xunit_parameterized_tests_simple.intermediate_results,
        test_nodes
      )

      assert.are.same(expected_results, actual_results)
    end
  )

  it("should correctly convert simple ClassData intermediate results to neotest-results", function()
    local test_tree = Tree.from_list(
      test_node_mocks.xunit_classdata_tests_simple.node_list,
      function(pos)
        return pos.id
      end
    )

    local test_nodes = neotest_node_tree_utils.get_test_nodes_data(test_tree)

    local expected_results = {
      ["/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ClassDataTests.cs::XUnitSamples::ClassDataTests::Theory_With_Class_Data_Test"] = {
        errors = {
          {
            message = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -2, v2: 2): Assert.True() Failure\nExpected: True\nActual:   False\nat XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(Int32 v1, Int32 v2) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ClassDataTests.cs:line 14",
          },
          {
            message = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -4, v2: 6): Assert.True() Failure\nExpected: True\nActual:   False\nat XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(Int32 v1, Int32 v2) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ClassDataTests.cs:line 14",
          },
        },
        short = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test:failed",
        status = "failed",
      },
    }
    local actual_results = ResultUtils.convert_intermediate_results(
      test_node_mocks.xunit_classdata_tests_simple.intermediate_results,
      test_nodes
    )

    assert.are.same(expected_results, actual_results)
  end)
end)
