local logger = require("neotest.logging")
local async = require("neotest.async")

local result_utils = {}
local highlight_indicator = "\27[39;49m\27"
local highlight_reset_matcher = "\27%[39%;49m"
local failure_indicator = highlight_indicator .. "[91m  Failed"
local failure_highlight = highlight_indicator .. "[91m"
local pass_indicator = highlight_indicator .. "[92m  Passed"
local pass_highlight = highlight_indicator .. "[92m"
local skipped_indicator = highlight_indicator .. "[93m  Skipped"
local skipped_highlight = highlight_indicator .. "[93m"
local end_marker = "\r\n\r\n\27[39;49m\r\n\27[39;49m\27"

---@class IntermediateResults
---@field passed DotnetResult
---@field failed DotnetResult
---@field skipped DotnetResult

---@class DotnetResult
---@field status string
---@field raw_output string
---@field test_name string
local function gather_tests_by_outcome(output, test_outcome_indicator)
  ---@type IntermediateResults
  local intermediate_results = { passed = {}, failed = {}, skipped = {} }

  local raw_outputs = {}
  local search_idx = 0
  while true do
    local start_idx = string.find(output, pass_indicator, search_idx + 1, true)
    local end_idx = -1

    if start_idx then
      end_idx = string.find(output, failure_indicator, search_idx + 1, true)
        or string.find(output, skipped_indicator, search_idx + 1, true)
        or string.find(output, end_marker, search_idx + 1, true)
    else
      start_idx = string.find(output, failure_indicator, search_idx + 1, true)
    end

    if start_idx then
      end_idx = string.find(output, pass_indicator, search_idx + 1, true)
        or string.find(output, skipped_indicator, search_idx + 1, true)
        or string.find(output, end_marker, search_idx + 1, true)
    end
    if kk then
    end
    local end_idx = string.find(output, end_marker, start_idx + 1, true)
      or string.find(output, failure_indicator, search_idx + 1, true)
      or string.find(output, skipped_indicator, search_idx + 1, true)
      or string.find(output, pass_indicator, search_idx + 1, true)
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

function result_utils.marshal_dotnet_console_output(raw)
  put(raw)
  local output = to_cr_lines(raw)

  ---@type IntermediateResults
  local intermediate_results = { passed = {}, failed = {}, skipped = {} }
  local current_status
  local current_indicator
  local current_output = ""
  local current_test_name = ""

  for line in output do
    if not current_status then
      if string.find(line, failure_indicator, 1, true) then
        current_status = "failed"
        current_indicator = failure_highlight
      end
      if string.find(line, pass_indicator, 1, true) then
        put("Got a passed")
        put(line)
        current_status = "passed"
        current_indicator = pass_highlight
      end
      if string.find(line, skipped_indicator, 1, true) then
        current_status = "skipped"
        current_indicator = skipped_highlight
      end

      if current_status then
        local start_idx, end_idx = string.find(line, current_indicator, 1, true)
        current_test_name = string.match(line, "\27%[39%;49m([^%s]+)", end_idx)
        current_output = current_output .. line
      end
    else
      if string.find(line, current_indicator, 1, true) then
        current_output = current_output .. line
      else
        local result = {
          status = current_status,
          raw_output = current_output,
          test_name = current_test_name,
        }
        table.insert(intermediate_results[current_status], result)

        -- Reset the current result to collect the next one
        current_status = nil
        current_indicator = nil
        current_output = ""
        current_test_name = ""
      end
    end
  end

  put(intermediate_results)
  return intermediate_results
end

---Converts and adds the results of the test_results list to the neotest_results table.
---@param neotest_results neotest.Result[]
---@param test_results table<string, any>
---@param file_path string
---@return table<string, any>
function result_utils.convert_intermediate_results(output, test_nodes)
  local neotest_results = {}

  local output_lines = to_cr_lines(output)

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
          output = fname,
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
          output = fname,
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
