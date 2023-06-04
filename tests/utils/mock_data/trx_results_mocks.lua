local M = {}

---@type TrxMockData
M.xunit_classdata_tests_simple = {
  trx_results = {
    {
      Output = {
        ErrorInfo = {
          Message = "Assert.True() Failure\nExpected: True\nActual:   False",
          StackTrace = "at XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(Int32 v1, Int32 v2) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ClassDataTests.cs:line 14",
        },
      },
      _attr = {
        computerName = "pop-os",
        duration = "00:00:00.0018117",
        endTime = "2023-06-04T16:57:09.8954313+01:00",
        executionId = "671ed74f-42af-41b8-af88-d033def88221",
        outcome = "Failed",
        relativeResultsDirectory = "671ed74f-42af-41b8-af88-d033def88221",
        startTime = "2023-06-04T16:57:09.8954091+01:00",
        testId = "c01dbb41-e5dc-3e02-6d99-5f9c0dc3a7a0",
        testListId = "8c84fa94-04c1-424b-9868-57a2d4851a1d",
        testName = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -2, v2: 2)",
        testType = "13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b",
      },
    },
    {
      _attr = {
        computerName = "pop-os",
        duration = "00:00:00.0008118",
        endTime = "2023-06-04T16:57:09.8987894+01:00",
        executionId = "05fc0384-54fe-4d2a-ab37-9f3b4ffa3f89",
        outcome = "Passed",
        relativeResultsDirectory = "05fc0384-54fe-4d2a-ab37-9f3b4ffa3f89",
        startTime = "2023-06-04T16:57:09.8987894+01:00",
        testId = "0b2c52ec-acbf-6d07-4538-9af65da3289d",
        testListId = "8c84fa94-04c1-424b-9868-57a2d4851a1d",
        testName = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: 1, v2: 2)",
        testType = "13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b",
      },
    },
    {
      Output = {
        ErrorInfo = {
          Message = "Assert.True() Failure\nExpected: True\nActual:   False",
          StackTrace = "at XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(Int32 v1, Int32 v2) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ClassDataTests.cs:line 14",
        },
      },
      _attr = {
        computerName = "pop-os",
        duration = "00:00:00.0001265",
        endTime = "2023-06-04T16:57:09.8990762+01:00",
        executionId = "c1cda8ac-257f-45d2-9b6a-3278e919a2f9",
        outcome = "Failed",
        relativeResultsDirectory = "c1cda8ac-257f-45d2-9b6a-3278e919a2f9",
        startTime = "2023-06-04T16:57:09.8990761+01:00",
        testId = "ee4d605d-f7ca-954f-c294-c06c86468395",
        testListId = "8c84fa94-04c1-424b-9868-57a2d4851a1d",
        testName = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -4, v2: 6)",
        testType = "13cdc9d9-ddb5-4fa4-a97d-d965ccfc6d4b",
      },
    },
  },
  trx_test_definitions = {
    {
      Execution = {
        _attr = {
          id = "05fc0384-54fe-4d2a-ab37-9f3b4ffa3f89",
        },
      },
      TestMethod = {
        _attr = {
          adapterTypeName = "executor://xunit/VsTestRunner2/netcoreapp",
          className = "XUnitSamples.ClassDataTests",
          codeBase = "/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Theory_With_Class_Data_Test",
        },
      },
      _attr = {
        id = "0b2c52ec-acbf-6d07-4538-9af65da3289d",
        name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: 1, v2: 2)",
        storage = "/home/issafalcon/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
      },
    },
    {
      Execution = {
        _attr = {
          id = "671ed74f-42af-41b8-af88-d033def88221",
        },
      },
      TestMethod = {
        _attr = {
          adapterTypeName = "executor://xunit/VsTestRunner2/netcoreapp",
          className = "XUnitSamples.ClassDataTests",
          codeBase = "/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Theory_With_Class_Data_Test",
        },
      },
      _attr = {
        id = "c01dbb41-e5dc-3e02-6d99-5f9c0dc3a7a0",
        name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -2, v2: 2)",
        storage = "/home/issafalcon/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
      },
    },
    {
      Execution = {
        _attr = {
          id = "c1cda8ac-257f-45d2-9b6a-3278e919a2f9",
        },
      },
      TestMethod = {
        _attr = {
          adapterTypeName = "executor://xunit/VsTestRunner2/netcoreapp",
          className = "XUnitSamples.ClassDataTests",
          codeBase = "/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Theory_With_Class_Data_Test",
        },
      },
      _attr = {
        id = "ee4d605d-f7ca-954f-c294-c06c86468395",
        name = "XUnitSamples.ClassDataTests.Theory_With_Class_Data_Test(v1: -4, v2: 6)",
        storage = "/home/issafalcon/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
      },
    },
  },
}

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
          StackTrace = "at XUnitSamples.ParameterizedTests.Test1(Int32 value) in /home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/ParameterizedTests.cs:line 13",
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
          codeBase = "/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Test1",
        },
      },
      _attr = {
        id = "26bda926-2c36-936a-59ed-45ab600f3b44",
        name = "XUnitSamples.ParameterizedTests.Test1(value: 3)",
        storage = "/home/issafalcon/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
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
          codeBase = "/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Test1",
        },
      },
      _attr = {
        id = "29e20a39-c8e0-24b5-0775-a975ac621461",
        name = "XUnitSamples.ParameterizedTests.Test1(value: 2)",
        storage = "/home/issafalcon/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
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
          codeBase = "/home/issafalcon/repos/learning-dotnet/UnitTesting/XUnitSamples/bin/Debug/net6.0/XUnitSamples.dll",
          name = "Test1",
        },
      },
      _attr = {
        id = "e7aa3325-3472-fbf8-0fa4-7d51c72d859e",
        name = "XUnitSamples.ParameterizedTests.Test1(value: 1)",
        storage = "/home/issafalcon/repos/learning-dotnet/unittesting/xunitsamples/bin/debug/net6.0/xunitsamples.dll",
      },
    },
  },
}

return M
