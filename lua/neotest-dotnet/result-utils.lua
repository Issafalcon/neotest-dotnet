local result_utils = {}

---@class DotnetResult
---@field status string
---@field raw_output string
---@field test_name string
---@field error_info string

function result_utils.create_intermediate_results(test_results)
  local intermediate_results = {}
  for _, value in pairs(test_results) do
    if value._attr.testName ~= nil then
      local outcome = value._attr.outcome
      local has_errors = value.Output and value.Output.ErrorInfo or nil
      local intermediate_result = {
        status = string.lower(outcome),
        raw_output = value.Output and value.Output.StdOut or outcome,
        test_name = value._attr.testName,
        error_info = has_errors
            and value.Output.ErrorInfo.Message .. "\n" .. value.Output.ErrorInfo.StackTrace
          or nil,
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
      if intermediate_result.test_name == node.name then
        neotest_results[node.id] = {
          status = intermediate_result.status,
          short = node.name .. ":" .. intermediate_result.status,
          errors = {},
        }

        if intermediate_result.error_info then
          table.insert(neotest_results[node.id].errors, {
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
