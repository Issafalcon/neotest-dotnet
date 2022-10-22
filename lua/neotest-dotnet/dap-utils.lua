local M = {}

local debugStarted = false
local waitingForDebugger = false
local dotnet_test_pid

local install_dir = path.concat({ vim.fn.stdpath("data"), "mason" })

local function attach_and_display_output(test_output, debugger_code_window, cb)
  for _, output in ipairs(test_output) do
    print(output)
    dotnet_test_pid = dotnet_test_pid or string.match(output, "Process Id%p%s(%d+)")
    if
      string.find(output, "Waiting for debugger attach...")
      or string.find(output, "Please attach debugger")
    then
      waitingForDebugger = true
    end
  end
  if dotnet_test_pid ~= nil and waitingForDebugger and not debugStarted then
    debugStarted = true
    vim.schedule(function()
      vim.fn.win_gotoid(debugger_code_window)
      cb(dotnet_test_pid)
    end)
  end
end

M.get_dap_adapter_config = function(pid)
  return {
    type = "netcoredbg",
    name = "attach - netcoredbg",
    request = "attach",
    processId = pid,
  }
end

M.start_debuggable_test = function(cmd, strategy_cb)
  local initial_win_id = vim.fn.win_getid()
  vim.api.nvim_create_buf(false, true)
  vim.cmd("botright new")
  vim.cmd("resize " .. 5)

  vim.fn.termopen(cmd, {
    env = { ["VSTEST_HOST_DEBUG"] = "1", ["DOTNET_CLI_HOME"] = "/tmp" } or nil,
    on_stdout = function(_, return_val)
      attach_and_display_output(return_val, initial_win_id, strategy_cb)
    end,
    on_stderr = function(error, return_val)
      print(return_val)
      print(error)
    end,
    on_exit = function()
      waitingForDebugger = false
      dotnet_test_pid = nil
      debugStarted = false
    end,
  })
end

return M
