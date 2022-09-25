local result_utils = {}

---@class DotnetResult[]
---@field status string
---@field raw_output string
---@field test_name string
---@field error_info string

local outcome_mapper = {
  Passed = "passed",
  Failed = "failed",
  Skipped = "skipped",
  NotExecuted = "skipped",
}

function result_utils.get_runtime_error(position_id)
  local run_outcome = {}
  run_outcome[position_id] = {
    status = "failed",
  }
  return run_outcome
end

---Creates a table of intermediate results from the parsed xml result data
---@param test_results table
---@return DotnetResult[]
function result_utils.create_intermediate_results(test_results)
  ---@type DotnetResult[]
  local intermediate_results = {}

  for _, value in pairs(test_results) do
    if value._attr.testName ~= nil then
      local error_info
      local outcome = outcome_mapper[value._attr.outcome]
      local has_errors = value.Output and value.Output.ErrorInfo or nil

      if has_errors and outcome == 'failed' then
        local stackTrace = value.Output.ErrorInfo.StackTrace or ""
        error_info = value.Output.ErrorInfo.Message .. "\n" .. stackTrace
      end
      local intermediate_result = {
        status = string.lower(outcome),
        raw_output = value.Output and value.Output.StdOut or outcome,
        test_name = value._attr.testName,
        error_info = error_info,
      }
      table.insert(intermediate_results, intermediate_result)
    end
  end

  return intermediate_results
end

---Converts and adds the results of the test_results list to the neotest_results table.
---@param intermediate_results DotnetResult[] The marshalled dotnet console outputs
---@param test_nodes neotest.Tree
---@return neotest.Result[]
function result_utils.convert_intermediate_results(intermediate_results, test_nodes)
  local neotest_results = {}

  for _, intermediate_result in ipairs(intermediate_results) do
    for _, node in ipairs(test_nodes) do
      local node_data = node:data()
      -- The test name from the trx file uses the namespace to fully qualify the test name
      -- To simplify the comparison, it's good enough to just ensure that the last part of the test_name matches the node name (the unqualified display name of the test)
      if string.find(intermediate_result.test_name, node_data.name, -(#node_data.name), true) then
        neotest_results[node_data.id] = {
          status = intermediate_result.status,
          short = node_data.name .. ":" .. intermediate_result.status,
          errors = {},
        }

        if intermediate_result.error_info then
          table.insert(neotest_results[node_data.id].errors, {
            message = intermediate_result.error_info,
          })
        end

        break
      end
    end
  end

  return neotest_results
end

return result_utils
