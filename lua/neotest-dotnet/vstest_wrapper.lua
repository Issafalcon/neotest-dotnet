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

    local default_sdk_path
    if vim.fn.has("win32") then
      default_sdk_path = "C:/Program Files/dotnet/sdk/"
    else
      default_sdk_path = "/usr/local/share/dotnet/sdk/"
    end

    if not process or errors then
      M.sdk_path = default_sdk_path
      local log_string =
        string.format("neotest-dotnet: failed to detect sdk path. falling back to %s", M.sdk_path)

      vim.notify_once(log_string)
      logger.info(log_string)
    else
      local out = process.stdout.read()
      local match = out and out:match("Base Path:%s*(%S+[^\n]*)")
      if match then
        M.sdk_path = vim.trim(match)
        logger.info(string.format("neotest-dotnet: detected sdk path: %s", M.sdk_path))
      else
        M.sdk_path = default_sdk_path
        local log_string =
          string.format("neotest-dotnet: failed to detect sdk path. falling back to %s", M.sdk_path)
        vim.notify_once(log_string)
        logger.info(log_string)
      end
      process.close()
    end
  end

  return vim.fs.find("vstest.console.dll", { upward = false, type = "file", path = M.sdk_path })[1]
end

local function get_script(script_name)
  local script_paths = vim.api.nvim_get_runtime_file(vim.fs.joinpath("scripts", script_name), true)
  logger.debug("neotest-dotnet: possible scripts:")
  logger.debug(script_paths)
  for _, path in ipairs(script_paths) do
    if path:match("neotest%-dotnet") ~= nil then
      return path
    end
  end
end

---collects project information based on file
---@param path string
---@return { proj_file: string, dll_file: string, proj_dir: string }
function M.get_proj_info(path)
  local proj_file = vim.fs.find(function(name, _)
    return name:match("%.[cf]sproj$")
  end, { upward = true, type = "file", path = vim.fs.dirname(path) })[1]

  local _, res = lib.process.run({
    "dotnet",
    "msbuild",
    proj_file,
    "-getProperty:OutputPath",
    "-getProperty:AssemblyName",
    "-getProperty:TargetExt",
  }, {
    stderr = false,
    stdout = true,
  })

  local info = nio.fn.json_decode(res.stdout).Properties

  local dir_name = vim.fs.dirname(proj_file)

  local proj_data = {
    proj_file = proj_file,
    dll_file = vim.fs.joinpath(dir_name, info.OutputPath:gsub("\\", "/"), info.AssemblyName)
      .. info.TargetExt,
    proj_dir = dir_name,
  }

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

    logger.debug("neotest-dotnet: found discovery script: " .. test_discovery_script)
    logger.debug("neotest-dotnet: found testhost dll: " .. testhost_dll)

    local vstest_command = { "dotnet", "fsi", test_discovery_script, testhost_dll }

    logger.info("neotest-dotnet: starting vstest console with:")
    logger.info(vstest_command)

    local process = vim.system(vstest_command, {
      stdin = true,
      stdout = function(err, data)
        if data then
          logger.trace("neotest-dotnet: " .. data)
        end
        if err then
          logger.trace("neotest-dotnet " .. err)
        end
      end,
    }, function(obj)
      logger.warn("neotest-dotnet: vstest process died :(")
      logger.warn(obj.code)
      logger.warn(obj.signal)
      logger.warn(obj.stdout)
      logger.warn(obj.stderr)
    end)

    logger.info(string.format("neotest-dotnet: spawned vstest process with pid: %s", process.pid))

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
    if lib.files.exists(file_path) then
      spin_lock.with(function()
        file_exists = true
        content = lib.files.read(file_path)
      end)
    else
      tries = tries + 1
      nio.sleep(sleep_time)
    end
  end

  if not content then
    logger.warn(string.format("neotest-dotnet: timed out reading content of file %s", file_path))
  end

  return content
end

local discovery_cache = {}
local last_discovery = {}

---@class TestCase
---@field CodeFilePath string
---@field DisplayName string
---@field FullyQualifiedName string
---@field LineNumber integer

---@param path string
---@return table<string, TestCase> | nil test_cases map from id -> test case
function M.discover_tests(path)
  local json
  local proj_info = M.get_proj_info(path)

  if not proj_info.proj_file then
    logger.warn(string.format("neotest-dotnet: failed to find project file for %s", path))
    return {}
  end

  local path_open_err, path_stats = nio.uv.fs_stat(path)

  if
    not (
      not path_open_err
      and path_stats
      and path_stats.mtime
      and last_discovery[proj_info.proj_file]
      and path_stats.mtime.sec <= last_discovery[proj_info.proj_file]
    )
  then
    local exitCode, stdout = lib.process.run(
      { "dotnet", "build", proj_info.proj_file },
      { stdout = true, stderr = true }
    )
    logger.debug(string.format("neotest-dotnet: dotnet build status code: %s", exitCode))
    logger.debug(stdout)
  end

  proj_info = M.get_proj_info(path)

  if not proj_info.dll_file then
    logger.warn(string.format("neotest-dotnet: failed to find project dll for %s", path))
    return {}
  end

  local dll_open_err, dll_stats = nio.uv.fs_stat(proj_info.dll_file)
  assert(not dll_open_err, dll_open_err)

  local path_modified_time = dll_stats and dll_stats.mtime and dll_stats.mtime.sec

  if
    last_discovery[proj_info.proj_file]
    and path_modified_time
    and path_modified_time <= last_discovery[proj_info.proj_file]
  then
    logger.debug(
      string.format(
        "neotest-dotnet: cache hit for %s. %s - %s",
        proj_info.proj_file,
        path_modified_time,
        last_discovery[proj_info.proj_file]
      )
    )
    return discovery_cache[path]
  else
    logger.debug(
      string.format(
        "neotest-dotnet: cache miss for %s... path: %s cache: %s - %s",
        path,
        path_modified_time,
        proj_info.proj_file,
        last_discovery[proj_info.dll_file]
      )
    )
    logger.debug(last_discovery)
  end

  local dlls = {}

  if vim.tbl_isempty(discovery_cache) then
    local root = lib.files.match_root_pattern("*.sln")(path)
      or lib.files.match_root_pattern("*.[cf]sproj")(path)

    logger.debug(string.format("neotest-dotnet: root: %s", root))

    local projects = vim.fs.find(function(name, _)
      return name:match("%.[cf]sproj$")
    end, { type = "file", path = root, limit = math.huge })

    for _, project in ipairs(projects) do
      local dir_name = vim.fs.dirname(project)
      local proj_name = vim.fn.fnamemodify(project, ":t:r")

      local proj_dll_path =
        -- TODO: this might break if the project has been compiled as both Development and Release.
        vim.fs.find(function(name)
          return string.lower(name) == string.lower(proj_name .. ".dll")
        end, { type = "file", path = dir_name })[1]

      if proj_dll_path then
        dlls[#dlls + 1] = proj_dll_path
        local project_open_err, project_stats = nio.uv.fs_stat(proj_dll_path)
        last_discovery[project] = not project_open_err
          and project_stats
          and project_stats.mtime
          and project_stats.mtime.sec
      else
        logger.warn(string.format("neotest-dotnet: failed to find dll for %s", project))
      end
    end
  else
    dlls = { proj_info.dll_file }
    last_discovery[proj_info.proj_file] = path_modified_time
  end

  if vim.tbl_isempty(dlls) then
    return {}
  end

  local wait_file = nio.fn.tempname()
  local output_file = nio.fn.tempname()

  logger.debug("neotest-dotnet: found dlls:")
  logger.debug(dlls)

  local command = vim
    .iter({
      "discover",
      output_file,
      wait_file,
      dlls,
    })
    :flatten()
    :join(" ")

  logger.debug("neotest-dotnet: Discovering tests using:")
  logger.debug(command)

  invoke_test_runner(command)

  logger.debug("neotest-dotnet: Waiting for result file to populated...")

  local max_wait = 60 * 1000 -- 60 sec

  local done = M.spin_lock_wait_file(wait_file, max_wait)
  if done then
    local content = M.spin_lock_wait_file(output_file, max_wait)

    logger.debug("neotest-dotnet: file has been populated. Extracting test cases...")

    json = (content and vim.json.decode(content, { luanil = { object = true } })) or {}

    logger.debug("neotest-dotnet: done decoding test cases.")

    for file_path, test_map in pairs(json) do
      discovery_cache[file_path] = test_map
    end
  end

  return json and json[path]
end

---runs tests identified by ids.
---@param stream_path string
---@param output_path string
---@param process_output_path string
---@param ids string|string[]
---@return string wait_file
function M.run_tests(stream_path, output_path, process_output_path, ids)
  lib.process.run({ "dotnet", "build" })

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
  invoke_test_runner(command)

  return output_path
end

--- Uses the vstest console to spawn a test process for the debugger to attach to.
---@param attached_path string
---@param stream_path string
---@param output_path string
---@param ids string|string[]
---@return string? pid
function M.debug_tests(attached_path, stream_path, output_path, ids)
  lib.process.run({ "dotnet", "build" })

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

  invoke_test_runner(command)

  logger.debug("neotest-dotnet: Waiting for pid file to populate...")

  local max_wait = 30 * 1000 -- 30 sec

  return M.spin_lock_wait_file(pid_path, max_wait)
end

return M
