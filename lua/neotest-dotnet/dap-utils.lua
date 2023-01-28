local logger = require("neotest.logging")

local M = {}

local debugStarted = false
local waitingForDebugger = false
local dotnet_test_pid

--- Checks the output from the dotnet test process for certain key phrases that
--- indicates the test process is ready to have a dap adapter attached
---@param test_output string The output line from the running test process
---@param code_window_id number The ID of the original window the user was in when running the debug request
---@param cb function The callback to run when the test process is ready to attach to:
---   Signature format is function(process_id), where process_id is the ID of the dotnet test process
local function wait_until_attachable(test_output, code_window_id, cb)
  for _, output in ipairs(test_output) do
    dotnet_test_pid = dotnet_test_pid or string.match(output, "Process Id%p%s(%d+)")

    if
      string.find(output, "Waiting for debugger attach...")
      or string.find(output, "Please attach debugger")
    then
      waitingForDebugger = true
    end
  end
  if dotnet_test_pid ~= nil and waitingForDebugger and not debugStarted then
    logger.debug("neotest-dotnet: Dotnet test process ID: " .. dotnet_test_pid)
    debugStarted = true
    vim.schedule(function()
      vim.fn.win_gotoid(code_window_id)
      cb(dotnet_test_pid)
    end)
  end
end

--- Return the netcoredbg adapter config to attach to the running dotnet test process
---@param pid string The process id of the dotnet test process
---@param usr_args table The user arguments to pass to the adapter
---@return table The adapter config
M.get_dap_adapter_config = function(pid, usr_args)
  return vim.tbl_extend("keep", {
    type = "netcoredbg",
    name = "attach - netcoredbg",
    request = "attach",
    processId = pid,
  }, usr_args or {})
end

--- Start the dotnet test process in debug mode and capture the PID of the internal test process
--- in order for neotest to be able to attach to it.
---@param cmd string The dotnet test comman to run
---@param strategy_cb function The callback to run when the test process is ready to attach to:
---   Signature format is function(process_id), where process_id is the ID of the dotnet test process---@param _
M.start_debuggable_test = function(cmd, strategy_cb)
  local initial_win_id = vim.fn.win_getid()
  vim.api.nvim_create_buf(false, true)
  vim.cmd("botright new")
  vim.cmd("resize " .. 5)

  vim.fn.termopen(cmd, {
    env = { ["VSTEST_HOST_DEBUG"] = "1" } or nil,
    on_stdout = function(_, return_val)
      wait_until_attachable(return_val, initial_win_id, strategy_cb)
    end,
    on_stderr = function(error, return_val) end,
    on_exit = function()
      waitingForDebugger = false
      dotnet_test_pid = nil
      debugStarted = false
    end,
  })
end

return M
