local nio = require("nio")
local lib = require("neotest.lib")
local logger = require("neotest.logging")

local M = {}

local function get_script(script_name)
  local script_paths = vim.api.nvim_get_runtime_file(script_name, true)
  for _, path in ipairs(script_paths) do
    if vim.endswith(path, ("neotest-dotnet%s" .. script_name):format(lib.files.sep)) then
      return path
    end
  end
end

local test_runner
local semaphore = nio.control.semaphore(1)

local function invoke_test_runner(command)
  semaphore.with(function()
    if test_runner ~= nil then
      return
    end

    local test_discovery_script = get_script("run_tests.fsx")
    local testhost_dll = "/usr/local/share/dotnet/sdk/8.0.401/vstest.console.dll"

    local process = vim.system({ "dotnet", "fsi", test_discovery_script, testhost_dll }, {
      stdin = true,
      stdout = function(err, data)
        logger.trace(data)
        logger.trace(err)
      end,
    }, function(obj)
      logger.warn("vstest process died :(")
      logger.warn(obj.code)
      logger.warn(obj.signal)
      logger.warn(obj.stdout)
      logger.warn(obj.stderr)
    end)

    logger.info(string.format("spawned vstest process with pid: %s", process.pid))

    test_runner = function(content)
      process:write(content .. "\n")
    end
  end)

  return test_runner(command)
end

local spin_lock = nio.control.semaphore(1)

---Repeatly tries to read content. Repeats untill the file is non-empty or operation times out.
---@param file_path string
---@param max_wait integer maximal time to wait for the file to populated in miliseconds.
---@return string
function M.spin_lock_wait_file(file_path, max_wait)
  local content

  local sleep_time = 25 -- scan every 25 ms
  local tries = 1
  local file_exists = false

  while not file_exists and tries * sleep_time < max_wait do
    if vim.fn.filereadable(file_path) == 1 then
      spin_lock.with(function()
        local file, open_err = nio.file.open(file_path)
        assert(not open_err, open_err)
        file_exists = true
        content = file.read()
        file.close()
      end)
    else
      tries = tries + 1
      nio.sleep(sleep_time)
    end
  end

  return content
end

local discovery_cache = {}
local discovery_lock = nio.control.semaphore(1)

---@param proj_file string
---@return table test_cases
function M.discover_tests(proj_file)
  local output_file = nio.fn.tempname()

  local dir_name = vim.fs.dirname(proj_file)
  local proj_name = vim.fn.fnamemodify(proj_file, ":t:r")

  local proj_dll_path =
    vim.fs.find(proj_name .. ".dll", { upward = false, type = "file", path = dir_name })[1]

  lib.process.run({ "dotnet", "build", proj_file })

  local json

  discovery_lock.with(function()
    local open_err, stats = nio.uv.fs_stat(proj_dll_path)
    assert(not open_err, open_err)

    local cached = discovery_cache[proj_dll_path]
    local modified_time = stats.mtime and stats.mtime.sec

    if
      cached
      and cached.last_modified
      and modified_time
      and modified_time <= cached.last_modified
    then
      logger.debug("cache hit")
      json = cached.content
      return
    end

    logger.debug(
      string.format(
        "cache not hit: %s %s %s",
        proj_dll_path,
        cached and cached.last_modified,
        modified_time
      )
    )

    local command = vim
      .iter({
        "discover",
        output_file,
        proj_dll_path,
      })
      :flatten()
      :join(" ")

    logger.debug("Discovering tests using:")
    logger.debug(command)

    invoke_test_runner(command)

    logger.debug("Waiting for result file to populate...")

    local max_wait = 10 * 1000 -- 10 sec

    json = vim.json.decode(
      M.spin_lock_wait_file(output_file, max_wait),
      { luanil = { object = true } }
    ) or {}

    logger.debug("file has been populated. Extracting test cases")

    discovery_cache[proj_dll_path] = {
      last_modified = modified_time,
      content = json,
    }
  end)

  return json
end

---runs tests identified by ids.
---@param ids string|string[]
---@param stream_path string
---@param output_path string
---@return string command
function M.run_tests(ids, stream_path, output_path)
  lib.process.run({ "dotnet", "build" })

  local command = vim
    .iter({
      "run-tests",
      stream_path,
      output_path,
      ids,
    })
    :flatten()
    :join(" ")
  invoke_test_runner(command)

  return string.format("tail -n 1 -f %s", output_path, output_path)
end

---Uses the vstest console to spawn a test process for the debugger to attach to.
---@param pid_path string
---@param attached_path string
---@param stream_path string
---@param output_path string
---@param ids string|string[]
---@return integer pid
function M.debug_tests(pid_path, attached_path, stream_path, output_path, ids)
  lib.process.run({ "dotnet", "build" })

  local command = vim
    .iter({
      "debug-tests",
      pid_path,
      attached_path,
      stream_path,
      output_path,
      ids,
    })
    :flatten()
    :join(" ")
  logger.debug("starting test in debug mode using:")
  logger.debug(command)

  invoke_test_runner(command)

  logger.debug("Waiting for pid file to populate...")

  local max_wait = 30 * 1000 -- 30 sec

  return M.spin_lock_wait_file(pid_path, max_wait)
end

return M
