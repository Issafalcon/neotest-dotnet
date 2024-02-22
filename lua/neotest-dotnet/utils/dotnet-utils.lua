local nio = require("nio")
local async = require("neotest.async")
local FanoutAccum = require("neotest.types").FanoutAccum
local logger = require("neotest.logging")

local DotNetUtils = {}

function DotNetUtils.get_test_full_names(project_path)
  local data_accum = FanoutAccum(function(prev, new)
    if not prev then
      return new
    end
    return prev .. new
  end, nil)

  local stream_path = vim.fn.tempname()
  local open_err, stream_fd = async.uv.fs_open(stream_path, "w", 438)
  assert(not open_err, open_err)

  data_accum:subscribe(function(data)
    vim.loop.fs_write(stream_fd, data, nil, function(write_err)
      assert(not write_err, write_err)
    end)
  end)

  local test_names_started = false
  local finish_future = async.control.future()
  local result_code

  local test_command = "dotnet test -t " .. project_path .. " -- NUnit.DisplayName=FullName"
  local success, job = pcall(nio.fn.jobstart, test_command, {
    pty = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if test_names_started then
          -- Trim leading and trailing whitespace before writing
          line = line:gsub("^%s*(.-)%s*$", "%1")
          data_accum:push(line .. "\n")
        end
        if line:find("The following Tests are available") then
          test_names_started = true
        end
      end
    end,
    on_exit = function(_, code)
      result_code = code
      finish_future.set()
    end,
  })

  if not success then
    local write_err, _ = nio.uv.fs_write(stream_fd, job)
    assert(not write_err, write_err)
    result_code = 1
    finish_future.set()
  end

  return {
    is_complete = function()
      return result_code ~= nil
    end,
    result = function()
      finish_future:wait()
      local close_err = nio.uv.fs_close(stream_fd)
      assert(not close_err, close_err)
      pcall(nio.fn.chanclose, job)
      local output = nio.fn.readfile(stream_path)

      logger.debug("DotNetUtils.get_test_full_names output: ")
      logger.debug(output)
      return {
        result_code = result_code,
        output = output,
      }
    end,
  }
end

return DotNetUtils
