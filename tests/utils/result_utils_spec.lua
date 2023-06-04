describe("create_intermediate_results_xunit", function()
  local ResultUtils = require("neotest-dotnet.utils.result-utils")
  local trx_result_mocks = require("tests.utils.mock_data.trx_results_mocks")

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
          error_info = "Assert.True() Failure\nExpected: True\nActual:   False\nat XUnitSamples.ParameterizedTests.Test1(Int32 value) in /home/adam/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs:line 13",
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
end)
