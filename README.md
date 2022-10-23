# Neotest .NET

Neotest adapter for dotnet tests

**NOTE - This is a WIP project and will be under development over the coming months with additional features**

- _Please feel free to open an issue_

# Pre-requisites

neotest-dotnet requires makes a number of assumptions about your environment:

1. Omnisharp-LSP is installed and active in the current buffer
2. The `dotnet sdk` is installed and the `dotnet` executable is on the users runtime path (future updates may allow customisation of the dotnet exe location)
3. The user is running tests using one of the supported test runners / frameworks (see support grid)

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

# Support

## Key

:heavy_check_mark: = Fully supported

:part_alternation_mark: = Partially Supported (functionality might behave unusually)

:interrobang: = As yet untested

:x: = Unsupported (tested)

| Runner / Framework | Unit Tests         | Parameterized Unit Tests (e.g. Using `TestCase` attribute) | Specflow           | Debugging          |
| ------------------ | ------------------ | ---------------------------------------------------------- | ------------------ | ---------          |
| C# - NUnit         | :heavy_check_mark: | :x:                                                        | :heavy_check_mark: | :x:                |
| C# - XUnit         | :heavy_check_mark: | :heavy_check_mark:                                         | :heavy_check_mark: | :heavy_check_mark: |
| C# - MSTest        | :heavy_check_mark: | :x:                                                        | :interrobang:      | :x:                |
| F# - NUnit         | :interrobang:      | :interrobang:                                              | :interrobang:      | :interrobang:      |
| F# - XUnit         | :interrobang:      | :interrobang:                                              | :interrobang:      | :interrobang:      |
| F# - MSTest        | :interrobang:      | :interrobang:                                              | :interrobang:      | :interrobang:      |


# Limitations

1. A tradeoff was made between being able to run parameterized tests and the specificity of the `dotnet --filter` command options. A more lenient 'contains' type filter is used
in order for the adapter to be able to work with parameterized tests. Unfortunately, no amount of formatting would support specific `FullyQualifiedName` filters for the dotnet test command for parameterized tests.
2. See the support guidance for feature and language support (regular users of F# needed!)
