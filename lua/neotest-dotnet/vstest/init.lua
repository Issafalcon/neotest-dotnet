local nio = require("nio")
local logger = require("neotest.logging")
local cli_wrapper = require("neotest-dotnet.vstest.cli_wrapper")

local M = {}

---runs tests identified by ids.
---@param stream_path string
---@param output_path string
---@param process_output_path string
---@param ids string|string[]
---@return string wait_file
function M.run_tests(stream_path, output_path, process_output_path, ids)
  local command = vim
    .iter({
      "run-tests",
      stream_path,
      output_path,
      process_output_path,
      ids,
    })
    :flatten()
    :join(" ")
  cli_wrapper.invoke_test_runner(command)

  return output_path
end

--- Uses the vstest console to spawn a test process for the debugger to attach to.
---@param attached_path string
---@param stream_path string
---@param output_path string
---@param ids string|string[]
---@return string? pid
function M.debug_tests(attached_path, stream_path, output_path, ids)
  local process_output = nio.fn.tempname()

  local pid_path = nio.fn.tempname()

  local command = vim
    .iter({
      "debug-tests",
      pid_path,
      attached_path,
      stream_path,
      output_path,
      process_output,
      ids,
    })
    :flatten()
    :join(" ")
  logger.debug("neotest-dotnet: starting test in debug mode using:")
  logger.debug(command)

  cli_wrapper.invoke_test_runner(command)

  logger.debug("neotest-dotnet: Waiting for pid file to populate...")

  local max_wait = 30 * 1000 -- 30 sec

  return cli_wrapper.spin_lock_wait_file(pid_path, max_wait)
end

return M
