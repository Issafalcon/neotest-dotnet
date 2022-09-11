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

| Runner / Framework | Unit Tests         | Parameterized Unit Tests (e.g. Using `TestCase` attribute) | Specflow           |
| ------------------ | ------------------ | ---------------------------------------------------------- | ------------------ |
| C# - NUnit         | :heavy_check_mark: | :part_alternation_mark:                                    | :heavy_check_mark: |
| C# - XUnit         | :heavy_check_mark: | :part_alternation_mark:                                    | :heavy_check_mark: |
| C# - MSTest        | :heavy_check_mark: | :part_alternation_mark:                                    | :interrobang:      |
| F# - NUnit         | :interrobang:      | :interrobang:                                              | :interrobang:      |
| F# - XUnit         | :interrobang:      | :interrobang:                                              | :interrobang:      |
| F# - MSTest        | :interrobang:      | :interrobang:                                              | :interrobang:      |
