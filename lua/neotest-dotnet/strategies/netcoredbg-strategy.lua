local async = require("neotest.async")
local FanoutAccum = require("neotest.types").FanoutAccum

---@param spec neotest.RunSpec
---@return neotest.StrategyResult?
return function(spec)
  if vim.tbl_isempty(spec.strategy) then
    return
  end
  local dap = require("dap")

  local handler_id = "neotest_" .. async.fn.localtime()
  local data_accum = FanoutAccum(function(prev, new)
    if not prev then
      return new
    end
    return prev .. new
  end, nil)

  local output_path = vim.fn.tempname()
  local open_err, output_fd = async.uv.fs_open(output_path, "w", 438)
  assert(not open_err, open_err)

  data_accum:subscribe(function(data)
    local write_err, _ = async.uv.fs_write(output_fd, data)
    assert(not write_err, write_err)
  end)

  local finish_future = async.control.future()
  local result_code

  async.scheduler()
  dap.run(vim.tbl_extend("keep", spec.strategy, { env = spec.env, cwd = spec.cwd }), {
    before = function(config)
      dap.listeners.after.event_output[handler_id] = function(_, body)
        if vim.tbl_contains({ "stdout", "stderr" }, body.category) then
          async.run(function()
            data_accum:push(body.output)
          end)
        end
      end
      dap.listeners.after.event_exited[handler_id] = function(_, info)
        result_code = info.exitCode
        finish_future.set()
      end

      return adapter_before and adapter_before() or config
    end,
    after = function()
      dap.listeners.after.event_output[handler_id] = nil
      if adapter_after then
        adapter_after()
      end
    end,
  })
  return {
    is_complete = function()
      return result_code ~= nil
    end,
    output_stream = function()
      local queue = async.control.queue()
      data_accum:subscribe(queue.put)
      return function()
        return async.first({ finish_future.wait, queue.get })
      end
    end,
    output = function()
      return output_path
    end,
    attach = function()
      dap.repl.open()
    end,
    result = function()
      finish_future:wait()
      return result_code
    end,
  }
end
