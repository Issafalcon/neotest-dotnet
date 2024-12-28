describe("test cache should", function()
  local nio = require("nio")
  local cache = require("neotest-dotnet.vstest.discovery.cache")

  local sep = package.config:sub(1, 1)
  local test_file_path = "C:" .. sep .. "src" .. sep .. "CSharpTest" .. sep .. "CSharpTest.cs"

  nio.tests.it("return stored unix path", function()
    local sample_project = {
      proj_file = "C:\\src\\CSharpTest\\CSharpTest.csproj",
      dll_file = "C:\\src\\CSharpTest\\bin\\Debug\\net6.0\\CSharpTest.dll",
      is_test_project = true,
    }

    local test_cases = {
      ["C:/src/CSharpTest/CSharpTest.cs"] = {
        {
          CodeFilePath = "C:\\src\\CSharpTest\\CSharpTest.cs",
          DisplayName = "CSharpTest.CSharpTest.TestMethod1",
          FullyQualifiedName = "CSharpTest.CSharpTest.TestMethod1",
          LineNumber = 10,
        },
      },
    }

    cache.populate_discovery_cache(sample_project, test_cases, 0)

    local cached_test_cases = cache.get_cache_entry(sample_project, test_file_path)

    local expected = {
      {
        CodeFilePath = "C:\\src\\CSharpTest\\CSharpTest.cs",
        DisplayName = "CSharpTest.CSharpTest.TestMethod1",
        FullyQualifiedName = "CSharpTest.CSharpTest.TestMethod1",
        LineNumber = 10,
      },
    }

    assert.is_not_nil(cached_test_cases)
    assert.are_same(expected, cached_test_cases.TestCases)
  end)

  nio.tests.it("return stored windows path", function()
    local sample_project = {
      proj_file = "C:\\src\\CSharpTest\\CSharpTest.csproj",
      dll_file = "C:\\src\\CSharpTest\\bin\\Debug\\net6.0\\CSharpTest.dll",
      is_test_project = true,
    }

    local test_cases = {
      [vim.fs.normalize("C:\\src\\CSharpTest\\CSharpTest.cs", { win = true })] = {
        {
          CodeFilePath = "C:\\src\\CSharpTest\\CSharpTest.cs",
          DisplayName = "CSharpTest.CSharpTest.TestMethod1",
          FullyQualifiedName = "CSharpTest.CSharpTest.TestMethod1",
          LineNumber = 10,
        },
      },
    }

    cache.populate_discovery_cache(sample_project, test_cases, 0)

    local cached_test_cases = cache.get_cache_entry(sample_project, test_file_path)

    local expected = {
      {
        CodeFilePath = "C:\\src\\CSharpTest\\CSharpTest.cs",
        DisplayName = "CSharpTest.CSharpTest.TestMethod1",
        FullyQualifiedName = "CSharpTest.CSharpTest.TestMethod1",
        LineNumber = 10,
      },
    }

    assert.is_not_nil(cached_test_cases)
    assert.are_same(expected, cached_test_cases.TestCases)
  end)
end)
