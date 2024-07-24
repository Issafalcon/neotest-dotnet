local nio = require("nio")
local lib = require("neotest.lib")
local async = require("neotest.async")
local FanoutAccum = require("neotest.types").FanoutAccum
local logger = require("neotest.logging")

---@param spec neotest.RunSpec
---@return neotest.StrategyResult?
return function(spec)
  local dap = require("dap")

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

  local attach_win, attach_buf, attach_chan
  local finish_future = async.control.future()
  local debugStarted = false
  local waitingForDebugger = false
  local dotnet_test_pid
  local result_code

  logger.info("neotest-dotnet: Running tests in debug mode")

  local success, job = pcall(nio.fn.jobstart, spec.command, {
    cwd = spec.cwd,
    env = { ["VSTEST_HOST_DEBUG"] = "1" },
    pty = true,
    on_stdout = function(_, data)
      nio.run(function()
        data_accum:push(table.concat(data, "\n"))
      end)

      if not debugStarted then
        for _, output in ipairs(data) do
          dotnet_test_pid = dotnet_test_pid or string.match(output, "Process Id%p%s(%d+)")

          if
            string.find(output, "Waiting for debugger attach...")
            or string.find(output, "Please attach debugger")
            or string.find(output, "Process Id:")
          then
            waitingForDebugger = true
          end
        end
        if dotnet_test_pid ~= nil and waitingForDebugger then
          logger.debug("neotest-dotnet: Dotnet test process ID: " .. dotnet_test_pid)
          debugStarted = true

          dap.run(vim.tbl_extend("keep", {
            type = spec.dap.adapter_name,
            name = "attach - netcoredbg",
            request = "attach",
            processId = dotnet_test_pid,
          }, spec.dap.args or {}))
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
    output = function()
      return stream_path
    end,
    stop = function()
      nio.fn.jobstop(job)
    end,
    output_stream = function()
      local queue = nio.control.queue()
      data_accum:subscribe(function(d)
        queue.put(d)
      end)
      return function()
        return nio.first({ finish_future.wait, queue.get })
      end
    end,
    attach = function()
      if not attach_buf then
        attach_buf = nio.api.nvim_create_buf(false, true)
        attach_chan = lib.ui.open_term(attach_buf, {
          on_input = function(_, _, _, data)
            pcall(nio.api.nvim_chan_send, job, data)
          end,
        })
        data_accum:subscribe(function(data)
          nio.api.nvim_chan_send(attach_chan, data)
        end)
      end
      attach_win = lib.ui.float.open({
        buffer = attach_buf,
      })
      vim.api.nvim_buf_set_option(attach_buf, "filetype", "neotest-attach")
      attach_win:jump_to()
    end,
    result = function()
      if result_code == nil then
        finish_future:wait()
      end
      local close_err = nio.uv.fs_close(stream_fd)
      assert(not close_err, close_err)
      pcall(nio.fn.chanclose, job)
      if attach_win then
        attach_win:listen("close", function()
          pcall(vim.api.nvim_buf_delete, attach_buf, { force = true })
          pcall(vim.fn.chanclose, attach_chan)
        end)
      end
      return result_code
    end,
  }
end
