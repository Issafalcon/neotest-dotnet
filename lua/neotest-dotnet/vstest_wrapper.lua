local nio = require("nio")
local lib = require("neotest.lib")
local logger = require("neotest.logging")

local M = {}

M.sdk_path = nil

local function get_vstest_path()
  if not M.sdk_path then
    local process, errors = nio.process.run({
      cmd = "dotnet",
      args = { "--info" },
    })

    if not process or errors then
      if vim.fn.has("win32") then
        M.sdk_path = "C:/Program Files/dotnet/sdk/"
      else
        M.sdk_path = "/usr/local/share/dotnet/sdk/"
      end

      logger.info(string.format("failed to detect sdk path. falling back to %s", M.sdk_path))
    else
      local out = process.stdout.read()
      M.sdk_path = out and out:match("Base Path:%s*(%S+)")
      logger.info(string.format("detected sdk path: %s", M.sdk_path))
      process.close()
    end
  end

  return vim.fs.find("vstest.console.dll", { upward = false, type = "file", path = M.sdk_path })[1]
end

local function get_script(script_name)
  local script_paths = vim.api.nvim_get_runtime_file(script_name, true)
  for _, path in ipairs(script_paths) do
    if vim.endswith(path, ("neotest-dotnet%s" .. script_name):format(lib.files.sep)) then
      return path
    end
  end
end

local proj_file_path_map = {}

---collects project information based on file
---@param path string
---@return { proj_file: string, proj_name: string, dll_file: string, proj_dir: string }
function M.get_proj_info(path)
  if proj_file_path_map[path] then
    return proj_file_path_map[path]
  end

  local proj_file = vim.fs.find(function(name, _)
    return name:match("%.[cf]sproj$")
  end, { type = "file", path = vim.fs.dirname(path) })[1]

  local dir_name = vim.fs.dirname(proj_file)
  local proj_name = vim.fn.fnamemodify(proj_file, ":t:r")

  local proj_dll_path =
    -- TODO: this might break if the project has been compiled as both Development and Release.
    vim.fs.find(proj_name .. ".dll", { upward = false, type = "file", path = dir_name })[1]

  local proj_data = {
    proj_file = proj_file,
    proj_name = proj_name,
    dll_file = proj_dll_path,
    proj_dir = dir_name,
  }

  proj_file_path_map[path] = proj_data
  return proj_data
end

local test_runner
local semaphore = nio.control.semaphore(1)

local function invoke_test_runner(command)
  semaphore.with(function()
    if test_runner ~= nil then
      return
    end

    local test_discovery_script = get_script("run_tests.fsx")
    local testhost_dll = get_vstest_path()

    local vstest_command = { "dotnet", "fsi", test_discovery_script, testhost_dll }

    logger.info("starting vstest console with:")
    logger.info(vstest_command)

    local process = vim.system(vstest_command, {
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

---Repeatly tries to read content. Repeats until the file is non-empty or operation times out.
---@param file_path string
---@param max_wait integer maximal time to wait for the file to populated in milliseconds.
---@return string?
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

---@param path string
---@return table test_cases
function M.discover_tests(path)
  local output_file = nio.fn.tempname()

  local proj_info = M.get_proj_info(path)

  lib.process.run({ "dotnet", "build", proj_info.proj_file })

  local json

  discovery_lock.with(function()
    local open_err, stats = nio.uv.fs_stat(proj_info.dll_file)
    assert(not open_err, open_err)

    local cached = discovery_cache[proj_info.dll_file]
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
        proj_info.dll_file,
        cached and cached.last_modified,
        modified_time
      )
    )

    local command = vim
      .iter({
        "discover",
        output_file,
        proj_info.dll_file,
      })
      :flatten()
      :join(" ")

    logger.debug("Discovering tests using:")
    logger.debug(command)

    invoke_test_runner(command)

    logger.debug("Waiting for result file to populate...")

    local max_wait = 10 * 1000 -- 10 sec

    local content = M.spin_lock_wait_file(output_file, max_wait)

    json = (content and vim.json.decode(content, { luanil = { object = true } })) or {}

    logger.debug("file has been populated. Extracting test cases")

    discovery_cache[proj_info.dll_file] = {
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
---@return string? pid
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
