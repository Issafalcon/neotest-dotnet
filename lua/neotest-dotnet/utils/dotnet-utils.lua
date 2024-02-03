local nio = require("nio")
local async = require("neotest.async")
local FanoutAccum = require("neotest.types").FanoutAccum
local logger = require("neotest.logging")

local DotNetUtils = {}

-- Write function that use nio to run dotnet test -t in --no-build in the background and saves output to a temp file
function DotNetUtils.get_test_full_names(project_path, output_file)
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
    local write_err, _ = async.uv.fs_write(stream_fd, data)
    assert(not write_err, write_err)
  end)

  local test_names_started = false
  local finish_future = async.control.future()
  local result_code

  local test_command = "dotnet test -t " .. project_path .. "-- NUnit.DisplayName=FullName"
  local success, job = pcall(nio.fn.jobstart, test_command, {
    cwd = project_path,
    pty = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if test_names_started then
          nio.run(function()
            data_accum:push(table.concat(data, "\n"))
          end)
        end
        if line:find("The following Tests are available") then
          test_names_started = false
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
      if result_code == nil then
        finish_future:wait()
      end
      local close_err = nio.uv.fs_close(stream_fd)
      assert(not close_err, close_err)
      pcall(nio.fn.chanclose, job)
      return {
        result_code = result_code,
        output = nio.fn.readfile(stream_path),
      }
    end,
  }
end

return DotNetUtils
