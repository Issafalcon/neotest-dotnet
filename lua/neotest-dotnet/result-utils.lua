local logger = require("neotest.logging")
local async = require("neotest.async")

local result_utils = {}
local failure_indicator = "\27[39;49m\27[91m  Failed"
local pass_indicator = "\27[39;49m\27[92m  Passed"
local skipped_indicator = "\27[39;49m\27[93m  Skipped"
local end_marker = "\r\n\r\n\27[39;49m\27[39;49m\27"

local function gather_tests_by_outcome(output, test_outcome_indicator)
  local raw_outputs = {}
  local search_idx = 0
  while true do
    local start_idx = string.find(output, test_outcome_indicator, search_idx + 1, true)
    if start_idx == nil then
      break
    end
    local end_idx = string.find(output, end_marker, start_idx + 1, true)
    -- or string.find(output, pass_indicator, search_idx + 1, true)
    -- or string.find(output, skipped_indicator, search_idx + 1, true)
    local result_str = string.sub(output, start_idx, end_idx or -1)
    search_idx = end_idx or -1

    table.insert(raw_outputs, result_str)
    if search_idx == -1 then
      -- End of the file
      break
    end
  end

  return raw_outputs
end

local function to_cr_lines(raw)
  return raw:gsub("\r", ""):gmatch("(.-)\n")
end
---Converts and adds the results of the test_results list to the neotest_results table.
---@param neotest_results neotest.Result[]
---@param test_results table<string, any>
---@param file_path string
---@return table<string, any>
function result_utils.marshal_dotnet_console_output(output, test_nodes)
  local neotest_results = {}

  -- Gather raw output of each test in the run
  local passed_raw = gather_tests_by_outcome(output, pass_indicator)
  local failed_raw = gather_tests_by_outcome(output, failure_indicator)
  local skipped_raw = gather_tests_by_outcome(output, skipped_indicator)

  for _, raw_output in ipairs(passed_raw) do
    for _, node in ipairs(test_nodes) do
      if string.find(raw_output, node.name) then
        local fname = async.fn.tempname()
        vim.fn.writefile({ raw_output }, fname, "b")
        neotest_results[node.id] = {
          status = "passed",
          short = node.name .. ":Passed",
          errors = {},
        }
        break
      end
    end
  end

  for _, raw_output in ipairs(failed_raw) do
    for _, node in ipairs(test_nodes) do
      if string.find(raw_output, node.name) then
        local fname = async.fn.tempname()

        -- Testing raw output
        put(raw_output)
        local CR_RAW = to_cr_lines(raw_output)
        local error_message = ""
        local error_lines = {}
        for line in CR_RAW do
          error_message = error_message .. line .. "\n"
          table.insert(error_lines, line)
        end
        async.fn.writefile(error_lines, fname)
        neotest_results[node.id] = {
          status = "failed",
          short = node.name .. ":Failed",
          errors = {
            {
              message = error_message,
            },
          },
        }
        break
      end
    end
  end

  put(neotest_results)
  return neotest_results
end

return result_utils
