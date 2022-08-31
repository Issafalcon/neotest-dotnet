local logger = require("neotest.logging")
local async = require("neotest.async")

local result_utils = {}
local highlight_indicator = "\27[39;49m\27"
local escaped_highlight_indicator = "\27%[39%;49m\27"
local highlight_reset_matcher = "\27%[39%;49m"

local failure_indicator = highlight_indicator .. "[91m  Failed"
local failure_highlight_escaped = escaped_highlight_indicator .. "%[91m"
local failure_highlight = highlight_indicator .. "[91m"

local pass_indicator = highlight_indicator .. "[92m  Passed"
local pass_highlight_escaped = escaped_highlight_indicator .. "%[92m"
local pass_highlight = highlight_indicator .. "[92m"

local skipped_indicator = highlight_indicator .. "[93m  Skipped"
local skipped_highlight_escaped = escaped_highlight_indicator .. "%[93m"
local skipped_highlight = highlight_indicator .. "[93m"

---@class DotnetResult
---@field status string
---@field raw_output string
---@field test_name string

local function to_cr_lines(raw)
  return raw:gsub("\r", ""):gmatch("(.-)\n")
end

local function check_for_test_line(line)
  local status = nil
  local indicator = nil

  if string.find(line, failure_indicator, 1, true) then
    status = "failed"
    indicator = failure_highlight
  end
  if string.find(line, pass_indicator, 1, true) then
    status = "passed"
    indicator = pass_highlight
  end
  if string.find(line, skipped_indicator, 1, true) then
    status = "skipped"
    indicator = skipped_highlight
  end

  return status, indicator
end

function result_utils.marshal_dotnet_console_output(raw)
  local output = to_cr_lines(raw)

  ---@type DotnetResult[]
  local intermediate_results = {}
  local current_status = nil
  local current_indicator = nil
  local current_output = ""
  local current_test_name = nil

  for line in output do
    if not current_status then
      current_status, current_indicator = check_for_test_line(line)

      if current_status then
        local _, end_idx = string.find(line, current_indicator, 0, true)
        current_test_name = string.match(line, highlight_reset_matcher .. "([^%s]+)", end_idx)
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
        table.insert(intermediate_results, result)

        -- Check the line again. We may be at the beginning of the next test output
        current_status, current_indicator = check_for_test_line(line)

        if current_status then
          local _, end_idx = string.find(line, current_indicator, 0, true)
          current_test_name = string.match(line, "\27%[39%;49m([^%s]+)", end_idx)
          current_output = line
        else
          -- Reset the current result to collect the next one
          current_status = nil
          current_indicator = nil
          current_output = ""
          current_test_name = nil
        end
      end
    end
  end

  put(intermediate_results)
  return intermediate_results
end

---Converts and adds the results of the test_results list to the neotest_results table.
---@param intermediate_results DotnetResult[] The marshalled dotnet console outputs
---@param test_nodes neotest.Tree
---@return neotest.Result[]
function result_utils.convert_intermediate_results(intermediate_results, test_nodes)
  local neotest_results = {}

  for _, result in ipairs(intermediate_results) do
    for _, node in ipairs(test_nodes) do
      if result.test_name == node.name then
        local sanitized_output = result.raw_output
          :gsub(failure_highlight_escaped, "")
          :gsub(pass_highlight_escaped, "")
          :gsub(skipped_highlight_escaped, "")
          :gsub(escaped_highlight_indicator, "")
          :gsub(highlight_reset_matcher, "")

        local fname = async.fn.tempname()
        async.fn.writefile({ result.raw_output }, fname)
        neotest_results[node.id] = {
          status = result.status,
          short = node.name .. ":Passed",
          output = fname,
          errors = {},
        }

        if result.status == "failed" then
          table.insert(neotest_results[node.id].errors, {
            message = sanitized_output,
          })
        end
        break
      end
    end
  end

  return neotest_results
end

return result_utils
