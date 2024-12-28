local nio = require("nio")
local logger = require("neotest.logging")
local file_utils = require("neotest-dotnet.files")

local M = {}

---@class TestCase
---@field CodeFilePath string
---@field DisplayName string
---@field FullyQualifiedName string
---@field LineNumber integer

---@class CacheEntry
---@field TestCases table<string, TestCase[]> map from file path to test cases
---@field LastModified integer unix timestamp of the project dll file was last modified

---@type table<string, TestCase[]> map from file path to test cases
local discovery_cache = {}

---@type table<string, integer>
local last_discovery = {}

local cache_semaphore = nio.control.semaphore(1)

---@param project DotnetProjectInfo
---@param test_cases table<string, TestCase[]>
---@param last_modified integer?
function M.populate_discovery_cache(project, test_cases, last_modified)
  cache_semaphore.with(function()
    last_discovery[project.proj_file] = last_modified or os.time()
    for path, test_case in pairs(test_cases) do
      discovery_cache[file_utils.abspath(path)] = test_case
    end
  end)
end

---@param project DotnetProjectInfo
---@param path string path to file extracting test cases for
---@return CacheEntry?
function M.get_cache_entry(project, path)
  cache_semaphore.acquire()

  local normalized_path = file_utils.abspath(path)

  local test_cases = discovery_cache[normalized_path]

  logger.trace(discovery_cache)
  logger.debug("Cache entry for " .. normalized_path)
  logger.debug(test_cases)

  cache_semaphore.release()

  return {
    TestCases = test_cases,
    LastModified = last_discovery[project.proj_file],
  }
end

return M
