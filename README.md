# Neotest .NET

Neotest adapter for dotnet tests

# Pre-requisites

TODO

# Installation

NOTE: The `xml2lua` luarocks module is required so the adapter can parse the `.trx` output from the tests. There are various ways
of installing this using neovim package managers.

## [Packer](https://github.com/wbthomason/packer.nvim)

- Packer comes with a builtin mechanism to install `luarocks` modules via `hererocks`

```
  use({
    "nvim-neotest/neotest",
    requires = {
      {
        "Issafalcon/neotest-dotnet", 
        rocks = { 'xml2lua' }
      },
    }
  })
```

## [vim-plug](https://github.com/junegunn/vim-plug)

TODO
