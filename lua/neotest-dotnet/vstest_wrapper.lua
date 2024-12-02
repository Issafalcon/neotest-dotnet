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
  logger.debug("possible scripts:")
  logger.debug(script_paths)
  for _, path in ipairs(script_paths) do
    if vim.endswith(path, ("neotest-dotnet%s" .. script_name):format(lib.files.sep)) then
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

  local dir_name = vim.fs.dirname(proj_file)
  local proj_name = vim.fn.fnamemodify(proj_file, ":t:r")

  local proj_dll_path =
    -- TODO: this might break if the project has been compiled as both Development and Release.
    vim.fs.find(function(name)
      return string.lower(name) == string.lower(proj_name .. ".dll")
    end, { type = "file", path = dir_name })[1]

  local proj_data = {
    proj_file = proj_file,
    dll_file = proj_dll_path,
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

    local test_discovery_script = get_script("scripts/run_tests.fsx")
    local testhost_dll = get_vstest_path()

    logger.debug("found discovery script: " .. test_discovery_script)
    logger.debug("found testhost dll: " .. testhost_dll)

    local vstest_command = { "dotnet", "fsi", test_discovery_script, testhost_dll }

    logger.info("starting vstest console with:")
    logger.info(vstest_command)

    local process = vim.system(vstest_command, {
      stdin = true,
      stdout = function(err, data)
        if data then
          logger.trace(data)
        end
        if err then
          logger.trace(err)
        end
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

  if not content then
    logger.warn(string.format("timed out reading content of file %s", file_path))
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
    logger.warn(string.format("failed to find project file for %s", path))
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
    logger.debug(string.format("dotnet build status code: %s", exitCode))
    logger.debug(stdout)
  end

  proj_info = M.get_proj_info(path)

  if not proj_info.dll_file then
    logger.warn(string.format("failed to find project dll for %s", path))
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
        "cache hit for %s. %s - %s",
        proj_info.proj_file,
        path_modified_time,
        last_discovery[proj_info.proj_file]
      )
    )
    return discovery_cache[path]
  else
    logger.debug(
      string.format(
        "cache miss for %s... path: %s cache: %s - %s",
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

    logger.debug(string.format("root: %s", root))

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
        logger.warn(string.format("failed to find dll for %s", project))
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

  logger.debug("found dlls:")
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

  logger.debug("Discovering tests using:")
  logger.debug(command)

  invoke_test_runner(command)

  logger.debug("Waiting for result file to populated...")

  local max_wait = 60 * 1000 -- 60 sec

  local done = M.spin_lock_wait_file(wait_file, max_wait)
  if done then
    local content = M.spin_lock_wait_file(output_file, max_wait)

    logger.debug("file has been populated. Extracting test cases...")

    json = (content and vim.json.decode(content, { luanil = { object = true } })) or {}

    logger.debug("done decoding test cases.")

    for file_path, test_map in pairs(json) do
      discovery_cache[file_path] = test_map
    end
  end

  return json and json[path]
end

---runs tests identified by ids.
---@param dap boolean true if normal test runner should be skipped
---@param stream_path string
---@param output_path string
---@param ids string|string[]
---@return string command
function M.run_tests(dap, stream_path, output_path, ids)
  if not dap then
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
  end

  return string.format("tail -n 1 -f %s", output_path, output_path)
end

--- Uses the vstest console to spawn a test process for the debugger to attach to.
---@param attached_path string
---@param stream_path string
---@param output_path string
---@param ids string|string[]
---@return string? pid
function M.debug_tests(attached_path, stream_path, output_path, ids)
  lib.process.run({ "dotnet", "build" })

  local pid_path = nio.fn.tempname()

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
