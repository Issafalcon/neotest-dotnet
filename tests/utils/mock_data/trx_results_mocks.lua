local M = {}

---@type TrxMockData
M.xunit_parameterized_tests_simple = {
  trx_results = {
    {
      _attr = {
        computerName = "pop-os",
        duration = "00:00:00.0005921",
        endTime = "2023-06-04T11:01:11.1960917+01:00",
        executionId = "3c44b8df-784b-452d-866c-eea8c4189a5e",
        outcome = "Passed",
        relativeResultsDirectory = "3c44b8df-784b-452d-866c-eea8c4189a5e",
        startTime = "2023-06-04T11:01:11.1960917+01:00",
        testId = "e7aa3325-3472-fbf8-0fa4-7d51c72d859e",
        testListId = "8c84fa94-04c1-424b-9868-57a2d4851a1d",
        testName = "XUnitSamples.ParameterizedTests.Test1(value: 1)",
        testType = "13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b",
      },
    },
    {
      Output = {
        ErrorInfo = {
          Message = "Assert.True() Failure\nExpected: True\nActual:   False",
          StackTrace = "at XUnitSamples.ParameterizedTests.Test1(Int32 value) in /home/adam/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs:line 13",
        },
      },
      _attr = {
        computerName = "pop-os",
        duration = "00:00:00.0028019",
        endTime = "2023-06-04T11:01:11.1927613+01:00",
        executionId = "d0a7aae8-7f4d-48d3-8793-38e40e3f4d7f",
        outcome = "Failed",
        relativeResultsDirectory = "d0a7aae8-7f4d-48d3-8793-38e40e3f4d7f",
        startTime = "2023-06-04T11:01:11.1927396+01:00",
        testId = "26bda926-2c36-936a-59ed-45ab600f3b44",
        testListId = "8c84fa94-04c1-424b-9868-57a2d4851a1d",
        testName = "XUnitSamples.ParameterizedTests.Test1(value: 3)",
        testType = "13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b",
      },
    },
    {
      _attr = {
        computerName = "pop-os",
        duration = "00:00:00.0000046",
        endTime = "2023-06-04T11:01:11.1962139+01:00",
        executionId = "128f4f9e-f109-4904-9094-2676a497a3fe",
        outcome = "Passed",
        relativeResultsDirectory = "128f4f9e-f109-4904-9094-2676a497a3fe",
        startTime = "2023-06-04T11:01:11.1962138+01:00",
        testId = "29e20a39-c8e0-24b5-0775-a975ac621461",
        testListId = "8c84fa94-04c1-424b-9868-57a2d4851a1d",
        testName = "XUnitSamples.ParameterizedTests.Test1(value: 2)",
        testType = "13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b",
      },
    },
  },
  trx_test_definitions = {
    {
      Execution = {
        _attr = {
          id = "d0a7aae8-7f4d-48d3-8793-38e40e3f4d7f",
        },
      },
      TestMethod = {
        _attr = {
          adapterTypeName = "executor://xunit/VsTestRunner2/netcoreapp",
          className = "XUnitSamples.ParameterizedTests",
          codeBase = "/home/adam/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Test1",
        },
      },
      _attr = {
        id = "26bda926-2c36-936a-59ed-45ab600f3b44",
        name = "XUnitSamples.ParameterizedTests.Test1(value: 3)",
        storage = "/home/adam/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
      },
    },
    {
      Execution = {
        _attr = {
          id = "128f4f9e-f109-4904-9094-2676a497a3fe",
        },
      },
      TestMethod = {
        _attr = {
          adapterTypeName = "executor://xunit/VsTestRunner2/netcoreapp",
          className = "XUnitSamples.ParameterizedTests",
          codeBase = "/home/adam/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Test1",
        },
      },
      _attr = {
        id = "29e20a39-c8e0-24b5-0775-a975ac621461",
        name = "XUnitSamples.ParameterizedTests.Test1(value: 2)",
        storage = "/home/adam/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
      },
    },
    {
      Execution = {
        _attr = {
          id = "3c44b8df-784b-452d-866c-eea8c4189a5e",
        },
      },
      TestMethod = {
        _attr = {
          adapterTypeName = "executor://xunit/VsTestRunner2/netcoreapp",
          className = "XUnitSamples.ParameterizedTests",
          codeBase = "/home/adam/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Test1",
        },
      },
      _attr = {
        id = "e7aa3325-3472-fbf8-0fa4-7d51c72d859e",
        name = "XUnitSamples.ParameterizedTests.Test1(value: 1)",
        storage = "/home/adam/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
      },
    },
  },
}

return M
