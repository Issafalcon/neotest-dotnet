local nio = require("nio")
local logger = require("neotest.logging")

local M = {}

function M.abspath(path)
  return vim.fs.normalize(path)
end

---return the unix timestamp of when the a file was last modified
---@async
---@param path string path to file
---@return integer?
function M.get_path_last_modified(path)
  local path_open_err, path_stats = nio.uv.fs_stat(path)
  if path_open_err or not path_stats then
    logger.debug("neotest-dotnet: failed to get file stats for " .. path)
    logger.debug(path_open_err)
    return nil
  end

  return path_stats.mtime and path_stats.mtime.sec
end

return M
