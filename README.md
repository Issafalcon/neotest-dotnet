<p align="center">
<a href="https://github.com/Issafalcon/neotest-dotnet/actions/workflows/main.yml">
  <img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/Issafalcon/neotest-dotnet/main.yml?label=main&style=for-the-badge">
</a>
<a href="https://github.com/Issafalcon/neotest-dotnet/releases">
  <img alt="GitHub release (latest SemVer)" src="https://img.shields.io/github/v/release/Issafalcon/neotest-dotnet?style=for-the-badge">
</a>
<a href="https://luarocks.org/modules/Issafalcon/neotest-dotnet">
  <img alt="LuaRocks Pacakage" src="https://img.shields.io/luarocks/v/Issafalcon/neotest-dotnet?logo=lua&color=purple&style=for-the-badge">
</a>
</p>

# Neotest .NET

Neotest adapter for dotnet tests

- Integrates with the VSTest runner to support all testing frameworks.
- DAP strategy for attaching debug adapter to test execution.

# Pre-requisites

neotest-dotnet requires makes a number of assumptions about your environment:

1. The `dotnet sdk` that is compatible with the current project is installed and the `dotnet` executable is on the users runtime path.
2. (For Debugging) `netcoredbg` is installed and `nvim-dap` plugin has been configured for `netcoredbg` (see debug config for more details)
3. Requires treesitter parser for either `C#` or `F#`
4. Requires `neovim v0.10.0` or later

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
      -- Path to dotnet sdk path.
      -- Used in cases where the sdk path cannot be auto discovered.
      sdk_path = "/usr/local/dotnet/sdk/9.0.101/"
    })
  }
})
```

# Debugging adapter

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

This adapter uses that standard dap strategy from `neotest`, which is run like so:

- `lua require("neotest").run.run({strategy = "dap"})`

# Contributing

Any help on this plugin would be very much appreciated.

## First steps

If you have a use case that the adapter isn't quite able to cover, a more detailed understanding of why can be achieved by following these steps:

1. Setting the `loglevel` property in your `neotest` setup config to `1` to reveal all the debug logs from neotest-dotnet
2. Open up your tests file and do what your normally do to run the tests
3. Look through the neotest log files for logs prefixed with `neotest-dotnet` (can be found by running the command `echo stdpath("log")`)
4. You should be able to piece together how the nodes in the neotest summary window are created (Using logs from tests that are "Found")

The general flow for test discovery and execution is as follows:

1. Spawn VSTest instance at start-up.
2. On test discovery: Send list of files to VSTest instance.
   - Once tests have been discovered the VSTest instance will write the discovered test cases to a file.
3. Read result file and parse tests.
4. Use treesitter to determine line ranges for test cases.
5. On test execution: Send list of test ids to VSTest instance.
   - Once test results are in the VSTest instance will write the results to a file.
6. Read test result file and parse results.

## Running tests

To run the tests from CLI, make sure that `luarocks` is installed and executable.
Then, Run `luarocks test` from the project root.

If you see a module 'busted.runner' not found error you need to update your `LUA_PATH`:

```sh
eval $(luarocks path --no-bin)
```
