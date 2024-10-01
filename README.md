<p align="center">
<a href="https://github.com/Issafalcon/neotest-dotnet/actions/workflows/main.yml">
  <img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/Issafalcon/neotest-dotnet/main.yml?label=main&style=for-the-badge">
</a>
<a href="https://github.com/Issafalcon/neotest-dotnet/releases">
  <img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/Issafalcon/neotest-dotnet?style=for-the-badge">
</a>
</p>

# Neotest .NET

Neotest adapter for dotnet tests

- Covers the "majority" of use cases for the 3 major .NET test runners
- Attempts to provide support for `SpecFlow` generated tests for the various test runners
  - Support for this may still be patchy, so please raise an issue if it doesn't behave as expected
  - `RunNearest` or `RunInFile` functions will need to be run from the _generated_ specflow tests (NOT the `.feature`)

# Pre-requisites

neotest-dotnet requires makes a number of assumptions about your environment:

1. The `dotnet sdk` that is compatible with the current project is installed and the `dotnet` executable is on the users runtime path (future updates may allow customisation of the dotnet exe location)
2. The user is running tests using one of the supported test runners / frameworks (see support grid)
3. (For Debugging) `netcoredbg` is installed and `nvim-dap` plugin has been configured for `netcoredbg` (see debug config for more details)
4. Requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) and the parser for C# or F#.

# Installation

## [Packer](https://github.com/wbthomason/packer.nvim)

```
  use({
    "nvim-neotest/neotest",
    requires = {
      {
        "Issafalcon/neotest-dotnet",
      },
    }
  })
```

## [vim-plug](https://github.com/junegunn/vim-plug)

```vim
    Plug 'https://github.com/nvim-neotest/neotest'
    Plug 'https://github.com/Issafalcon/neotest-dotnet'
```

# Usage

```lua
require("neotest").setup({
  adapters = {
    require("neotest-dotnet")
  }
})
```

Additional configuration settings can be provided:

```lua
require("neotest").setup({
  adapters = {
    require("neotest-dotnet")({
      dap = {
      -- Extra arguments for nvim-dap configuration
      -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
        args = {justMyCode = false },
      -- Enter the name of your dap adapter, the default value is netcoredbg
        adapter_name = "netcoredbg"
      },
      -- Let the test-discovery know about your custom attributes (otherwise tests will not be picked up)
      -- Note: Only custom attributes for non-parameterized tests should be added here. See the support note about parameterized tests
      custom_attributes = {
        xunit = { "MyCustomFactAttribute" },
        nunit = { "MyCustomTestAttribute" },
        mstest = { "MyCustomTestMethodAttribute" }
      },
      -- Provide any additional "dotnet test" CLI commands here. These will be applied to ALL test runs performed via neotest. These need to be a table of strings, ideally with one key-value pair per item.
      dotnet_additional_args = {
        "--verbosity detailed"
      },
      -- Tell neotest-dotnet to use either solution (requires .sln file) or project (requires .csproj or .fsproj file) as project root
      -- Note: If neovim is opened from the solution root, using the 'project' setting may sometimes find all nested projects, however,
      --       to locate all test projects in the solution more reliably (if a .sln file is present) then 'solution' is better.
      discovery_root = "project" -- Default
    })
  }
})
```

## Additional `dotnet test` arguments

As well as the `dotnet_additional_args` option in the adapter setup above, you may also provide additional CLI arguments as a table to each `neotest` command.
By doing this, the additional args provided in the setup function will be _replaced_ in their entirety by the ones provided at the command level.

For example, to provide a `runtime` argument to the `dotnet test` command, for all the tests in the file, you can run:

```lua
require("neotest").run.run({ vim.fn.expand("%"), dotnet_additional_args = { "--runtime win-x64" } })
```

**NOTE**:

- The `--logger` and `--results-directory` arguments, as well as the `--filter` expression are all added by the adapter, so changing any of these will likely result in errors in the adapter.
- Not all possible combinations of arguments will work with the adapter, as you might expect, given the way that output is specifically parsed and handled by the adapter.

# Debugging

[Debugging Using neotest dap strategy](https://user-images.githubusercontent.com/19861614/232598584-4d673050-989d-4a3e-ae67-8969821898ce.mp4)

- Install `netcoredbg` to a location of your choosing and configure `nvim-dap` to point to the correct path
- The example below uses the `mason.nvim` default install path:

```l
local install_dir = path.concat{ vim.fn.stdpath "data", "mason" }

dap.adapters.netcoredbg = {
  type = 'executable',
  command = install_dir .. '/packages/netcoredbg/netcoredbg',
  args = {'--interpreter=vscode'}
}
```

Neotest-Dotnet uses a custom strategy for debugging, as `netcoredbg` needs to attach to the running test. The test command is modified by setting the `VSTEST_HOST_DEBUG` env variable, which then waits for the debugger to attach.

To use the custom strategy, you no longer need to provide a custom command other than the standard neotest recommended one for debugging:

- `lua require("neotest").run.run({strategy = "dap"})`

The adapter will replace the standard `dap` strategy with the custom one automatically.

# Framework Support

The adapter supports `NUnit`, `xUnit` and `MSTest` frameworks, to varying degrees. Given each framework has their own test runner, and specific features and attributes, it is a difficult task to support all the possible use cases for each one.

To see if your use case is supported, check the grids below. If it isn't there, feel free to raise a ticket, or better yet, take a look at [how to contribute](#contributing) and raise a PR to support your use case!

## Key

:heavy_check_mark: = Fully supported

:part_alternation_mark: = Partially Supported (functionality might behave unusually)

:interrobang: = As yet untested

:x: = Unsupported (tested)

### NUnit

| Framework Feature            | Scope Level | Docs                                                                                                         | Status             | Notes                                                                                                                                                                                                                                                   |
| ---------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------ | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Test` (Attribute)           | Method      | [Test - Nunit](https://docs.nunit.org/articles/nunit/writing-tests/attributes/test.html)                     | :heavy_check_mark: | Supported when used inside a class with or without the `TestFixture` attribute decoration                                                                                                                                                               |
| `TestFixture` (Attribute)    | Class       | [TestFixture - Nunit](https://docs.nunit.org/articles/nunit/writing-tests/attributes/testfixture.html)       | :heavy_check_mark: |                                                                                                                                                                                                                                                         |
| `TestCase()` (Attribute)     | Method      | [TestCase - Nunit](https://docs.nunit.org/articles/nunit/writing-tests/attributes/testcase.html)             | :heavy_check_mark: | Support for parameterized tests with inline parameters. Supports neotest 'run nearest' and 'run file' functionality                                                                                                                                     |
| Nested Classes               | Class       |                                                                                                              | :heavy_check_mark: | Fully qualified name is corrected to include `+` when class is nested                                                                                                                                                                                   |
| `Theory` (Attribute)         | Method      | [Theory - Nunit](https://docs.nunit.org/articles/nunit/writing-tests/attributes/theory.html)                 | :x:                | Currently has conflicts with XUnits `Theory` which is more commonly used                                                                                                                                                                                |
| `TestCaseSource` (Attribute) | Method      | [TestCaseSource - NUnit](https://docs.nunit.org/articles/nunit/writing-tests/attributes/testcasesource.html) | :heavy_check_mark: | Bundles all dynamically parameterized tests under one neotest listing (short output contains errors for all tests. One test failure displays failure indicator for entire test "grouping"). Supports neotest 'run nearest' and 'run file' functionality |

### xUnit

| Framework Feature          | Scope Level | Docs                                                                                                                        | Status             | Notes                                                                                                                                                                                                                                                   |
| -------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Fact` (Attribute)         | Method      | [Fact - xUnit](https://xunit.net/docs/getting-started/netcore/cmdline#write-first-tests)                                    | :heavy_check_mark: |                                                                                                                                                                                                                                                         |
| `Theory` (Attribute)       | Method      | [Theory - xUnit](https://xunit.net/docs/getting-started/netcore/cmdline#write-first-theory)                                 | :heavy_check_mark: | Used in conjunction with the `InlineData()` attribute                                                                                                                                                                                                   |
| `InlineData()` (Attribute) | Method      | [Theory - xUnit](https://xunit.net/docs/getting-started/netcore/cmdline#write-first-theory)                                 | :heavy_check_mark: | Support for parameterized tests with inline parameters. Supports neotest 'run nearest' and 'run file' functionality                                                                                                                                     |
| `ClassData()` (Attribute)  | Method      | [ClassData - xUnit](https://andrewlock.net/creating-parameterised-tests-in-xunit-with-inlinedata-classdata-and-memberdata/) | :heavy_check_mark: | Bundles all dynamically parameterized tests under one neotest listing (short output contains errors for all tests. One test failure displays failure indicator for entire test "grouping"). Supports neotest 'run nearest' and 'run file' functionality |
| Nested Classes             | Class       |                                                                                                                             | :heavy_check_mark: | Fully qualified name is corrected to include `+` when class is nested                                                                                                                                                                                   |

### MSTest

| Framework Feature            | Scope Level | Docs                                                                                                                                                                   | Status             | Notes                                                                                                               |
| ---------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------- |
| `TestMethod` (Attribute)     | Method      | [TestMethod - MSTest](https://docs.nunit.org/articles/nunit/writing-tests/attributes/test.html)                                                                        | :heavy_check_mark: |                                                                                                                     |
| `TestClass` (Attribute)      | Class       | [TestClass - MSTest](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.testtools.unittesting.testclassattribute?view=visualstudiosdk-2022)           | :heavy_check_mark: |                                                                                                                     |
| Nested Classes               | Class       |                                                                                                                                                                        | :heavy_check_mark: | Fully qualified name is corrected to include `+` when class is nested                                               |
| `DataTestMethod` (Attribute) | Method      | [DataTestMethod - MSTest](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.testtools.unittesting.datatestmethodattribute?view=visualstudiosdk-2022) | :heavy_check_mark: |                                                                                                                     |
| `DataRow` (Attribute)        | Method      | [DataRow - MSTest](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.testtools.unittesting.datarowattribute?view=visualstudiosdk-2022)               | :heavy_check_mark: | Support for parameterized tests with inline parameters. Supports neotest 'run nearest' and 'run file' functionality |

# Limitations

1. A tradeoff was made between being able to run parameterized tests and the specificity of the `dotnet --filter` command options. A more lenient 'contains' type filter is used
   in order for the adapter to be able to work with parameterized tests. Unfortunately, no amount of formatting would support specific `FullyQualifiedName` filters for the dotnet test command for parameterized tests.
2. Dynamically parameterized tests need to be grouped together as neotest-dotnet is unable to robustly match the full test names that the .NET test runner attaches to the tests at runtime.
   - An attempt was made to use `dotnet test -t` to extract the dynamic test names, but this was too unreliable (duplicate test names were indistinguishable, and xUnit was the only runner that provided fully qualified test names)
3. See the support guidance for feature and language support
4. As mentioned in the **Debugging** section, there are some discrepancies in test output at the moment.

## NUnit Limitations

1. Using the `[Test]` attribute alongside `[TestCase]` attributes on the same method will cause `neotest-dotnet` to duplicate the item with erroneous nesting in the test structure. This will also break the ability of neotest to run the test cases e.g:

```c_sharp
    [Test]
    [TestCase(1)]
    [TestCase(2)]
    public void Test_With_Parameters(int a)
    {
        Assert.AreEqual(2, a);
    }
```

- The workaround is to instead, remove the redundant `[Test]` attribute.

# Contributing

Any help on this plugin would be very much appreciated. It has turned out to be a more significant effort to account for all the Microsoft `dotnet test` quirks
and various differences between each test runner, than I had initially imagined.

## First Steps

If you have a use case that the adapter isn't quite able to cover, a more detailed understanding of why can be achieved by following these steps:

1. Setting the `loglevel` property in your `neotest` setup config to `1` to reveal all the debug logs from neotest-dotnet
2. Open up your tests file and do what your normally do to run the tests
3. Look through the neotest log files for logs prefixed with `neotest-dotnet` (can be found by running the command `echo stdpath("log")`)
4. You should be able to piece together how the nodes in the neotest summary window are created (Using logs from tests that are "Found")

- The Tree for each test run is printed as a list (search for `Creating specs from tree`) from each test run
- The individual specs usually follow after in the log list, showing the command and context for each spec
- `TRX Results Output` can be searched to find out how neotest-dotnet is parsing the test output files
- Final results are tied back to the original list of discovered tests by using a set of conversion functions:
- `Test Nodes` are logged - these are taken from the original node tree list, and filtered to include only the test nodes and their children (if any)
- `Intermediate Results` are obtained and logged by parsing the TRX output into a list of test results
- The test nodes and intermediate results are passed to a function to correlate them with each other. If the test names in the nodes match the test names from the intermediate results, a final neotest-result for that test is returned and matched to the original test position from the very initial tree of nodes

Usually, if tests are not appearing in the `neotest` summary window, or are failing to be discovered by individual or grouped test runs, there will usually be an issue with one of the above steps. Carefully examining the names in the original node list and the names of the tests in each of the result lists, usually highighlights a mismatch.

5. Narrow down the function where you think the issue is.
6. Look through the unit tests (named by convention using `<filename_spec.lua>`) and check if there is a test case covering the use case for your situation
7. Write a test case that would enable your use case to be satisfied
8. See that the test fails
9. Try to fix the issue until the test passes

## Running Tests

To run the plenary tests from CLI, in the root folder, run

```
make test
```
