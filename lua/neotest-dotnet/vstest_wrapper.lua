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

function M.spin_lock_wait_file(file_path, max_wait)
  local json = {}

  local sleep_time = 25 -- scan every 25 ms
  local tries = 1
  local file_exists = false

  while not file_exists and tries * sleep_time < max_wait do
    if vim.fn.filereadable(file_path) == 1 then
      spin_lock.with(function()
        local file, open_err = nio.file.open(file_path)
        assert(not open_err, open_err)
        file_exists = true
        json = file.read()
        file.close()
      end)
    else
      tries = tries + 1
      nio.sleep(sleep_time)
    end
  end

  return json
end

function M.discover_tests(proj_file)
  local output_file = nio.fn.tempname()

  local dir_name = vim.fs.dirname(proj_file)
  local proj_name = vim.fn.fnamemodify(proj_file, ":t:r")

  local proj_dll_path =
    vim.fs.find(proj_name .. ".dll", { upward = false, type = "file", path = dir_name })[1]

  lib.process.run({ "dotnet", "build", proj_file })

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

  local json =
    vim.json.decode(M.spin_lock_wait_file(output_file, max_wait), { luanil = { object = true } })

  logger.debug("file has been populated. Extracting test cases")

  return json
end

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

return M
