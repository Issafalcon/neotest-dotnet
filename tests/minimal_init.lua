-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- When running headless only (i.e. via Makefile command)
if #vim.api.nvim_list_uis() == 0 then
  -- Add dependenices to rtp (installed via the Makefile 'deps' command)
  local neotest_path = vim.fn.getcwd() .. "/deps/neotest"
  local plenary_path = vim.fn.getcwd() .. "/deps/plenary"
  local treesitter_path = vim.fn.getcwd() .. "/deps/nvim-treesitter"
  local mini_path = vim.fn.getcwd() .. "/deps/mini.doc.nvim"
  local nio_path = vim.fn.getcwd() .. "/deps/nvim-nio"

  vim.cmd("set rtp+=" .. neotest_path)
  vim.cmd("set rtp+=" .. plenary_path)
  vim.cmd("set rtp+=" .. treesitter_path)
  vim.cmd("set rtp+=" .. mini_path)
  vim.cmd("set rtp+=" .. nio_path)

  -- Source the plugin dependency files
  vim.cmd("runtime plugin/nvim-treesitter.lua")
  vim.cmd("runtime plugin/plenary.vim")
  vim.cmd("runtime lua/mini/doc.lua")

  -- Setup test plugin dependencies
  require("nvim-treesitter.configs").setup({
    ensure_installed = "c_sharp",
    sync_install = true,
    highlight = {
      enable = false,
    },
  })
end
-- local M = {}
--
-- function M.root(root)
--   local f = debug.getinfo(1, "S").source:sub(2)
--   return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
-- end
--
-- ---@param plugin string
-- function M.load(plugin)
--   local name = plugin:match(".*/(.*)")
--   local package_root = M.root(".tests/site/pack/deps/start/")
--   if not vim.loop.fs_stat(package_root .. name) then
--     print("Installing " .. plugin)
--     vim.fn.mkdir(package_root, "p")
--     vim.fn.system({
--       "git",
--       "clone",
--       "--depth=1",
--       "https://github.com/" .. plugin .. ".git",
--       package_root .. "/" .. name,
--     })
--   end
-- end
--
-- function M.setup()
--   vim.cmd([[set runtimepath=$VIMRUNTIME]])
--   vim.opt.runtimepath:append(M.root())
--   vim.opt.packpath = { M.root(".tests/site") }
--
--   M.load("nvim-treesitter/nvim-treesitter")
--   M.load("nvim-lua/plenary.nvim")
--   M.load("Issafalcon/neotest-dotnet")
--   M.load("echasnovski/mini.doc")
-- end
--
-- M.setup()
