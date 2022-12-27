local M = {}

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

function M.get_runtime_error(position_id)
  local run_outcome = {}
  run_outcome[position_id] = {
    status = "failed",
  }
  return run_outcome
end

---Creates a table of intermediate results from the parsed xml result data
---@param test_results table
---@param test_definitions table
---@return DotnetResult[]
function M.create_intermediate_results(test_results, test_definitions)
  ---@type DotnetResult[]
  local intermediate_results = {}

  for _, value in pairs(test_results) do
    local qualified_test_name
    if(value._attr.testId ~= nil) then
      for _, test_definition in pairs(test_definitions) do 
        if(test_definition._attr.id ~= nil) then
          if(value._attr.testId == test_definition._attr.id) then
            local dot_index = string.find(test_definition._attr.name, "%.")
            local bracket_index = string.find(test_definition._attr.name, "%(")
            if(dot_index ~= nil and (bracket_index == nil or dot_index < bracket_index)) then 
              qualified_test_name = test_definition._attr.name
            else
              qualified_test_name = test_definition.TestMethod._attr.className.."."..test_definition._attr.name
            end
          end
        end
      end
    end
    if value._attr.testName ~= nil then
      local error_info
      local outcome = outcome_mapper[value._attr.outcome]
      local has_errors = value.Output and value.Output.ErrorInfo or nil

      if has_errors and outcome == "failed" then
        local stackTrace = value.Output.ErrorInfo.StackTrace or ""
        error_info = value.Output.ErrorInfo.Message .. "\n" .. stackTrace
      end
      local intermediate_result = {
        status = string.lower(outcome),
        raw_output = value.Output and value.Output.StdOut or outcome,
        test_name = qualified_test_name,
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
function M.convert_intermediate_results(intermediate_results, test_nodes)
  local neotest_results = {}

  for _, intermediate_result in ipairs(intermediate_results) do
    for _, node in ipairs(test_nodes) do
      local node_data = node:data()
      -- Use the full_name of the test, including namespace
      local is_match = #intermediate_result.test_name == #node_data.full_name
      and string.find(intermediate_result.test_name, node_data.full_name, 0, true)
      or string.find(intermediate_result.test_name, node_data.full_name, -#node_data.full_name, true)

      if is_match then
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

return M
