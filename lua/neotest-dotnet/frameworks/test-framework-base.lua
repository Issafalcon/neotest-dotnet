local xunit = require("neotest-dotnet.frameworks.xunit")
local nunit = require("neotest-dotnet.frameworks.nunit")
local mstest = require("neotest-dotnet.frameworks.mstest")
local attributes = require("neotest-dotnet.frameworks.test-attributes")
local async = require("neotest.async")

local TestFrameworkBase = {}

function TestFrameworkBase.get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
  end
  if captured_nodes["class.name"] then
    return "class"
  end
  if captured_nodes["test.parameterized.name"] then
    return "test.parameterized"
  end
end

function TestFrameworkBase.position_id(position, parents)
  local original_id = position.path
  local has_parent_class = false
  local sep = "::"

  -- Build the original ID from the parents, changing the separator to "+" if any nodes are nested classes
  for _, node in ipairs(parents) do
    if has_parent_class and node.is_class then
      sep = "+"
    end

    if node.is_class then
      has_parent_class = true
    end

    original_id = original_id .. sep .. node.name
  end

  -- Add the final leaf nodes name to the ID, again changing the separator to "+" if it is a nested class
  sep = "::"
  if has_parent_class and position.is_class then
    sep = "+"
  end
  original_id = original_id .. sep .. position.name

  -- Check to see if the position is a test case and contains parentheses (meaning it is parameterized)
  -- If it is, remove the duplicated parent test name from the ID, so that when reading the trx test name
  -- it will be the same as the test name in the test explorer
  -- Example:
  --  When ID is "/path/to/test_file.cs::TestNamespace::TestClassName::ParentTestName::ParentTestName(TestName)"
  --  Then we need it to be converted to "/path/to/test_file.cs::TestNamespace::TestClassName::ParentTestName(TestName)"
  if position.type == "test" and position.name:find("%(") then
    local id_segments = {}
    for _, segment in ipairs(vim.split(original_id, "::")) do
      table.insert(id_segments, segment)
    end

    table.remove(id_segments, #id_segments - 1)
    return table.concat(id_segments, "::")
  end

  return original_id
end

---Builds a position from captured nodes, optionally parsing parameters to create sub-positions.
---@param file_path any
---@param source any
---@param captured_nodes any
---@return table
function TestFrameworkBase.build_position(file_path, source, captured_nodes)
  local match_type = TestFrameworkBase.get_match_type(captured_nodes)

  local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
  local display_name = nil

  if captured_nodes["display_name"] then
    display_name = vim.treesitter.get_node_text(captured_nodes["display_name"], source)
  end

  local definition = captured_nodes[match_type .. ".definition"]

  -- Introduce the C# concept of a "class" to the node, so we can distinguish between a class and a namespace.
  --  Helps to determine if classes are nested, and therefore, if we need to modify the ID of the node (nested classes denoted by a '+' in C# test naming convention)
  local is_class = match_type == "class"

  -- Swap the match type back to "namespace" so neotest core can handle it properly
  if match_type == "class" then
    match_type = "namespace"
  end

  local node = {
    type = match_type,
    is_class = is_class,
    display_name = display_name,
    path = file_path,
    name = name,
    range = { definition:range() },
  }

  if match_type and match_type ~= "test.parameterized" then
    return node
  end

  return TestFrameworkBase.get_test_framework_utils(source)
    .build_parameterized_test_positions(node, source, captured_nodes, match_type)
end

---Creates a table of intermediate results from the parsed xml result data
---@param test_results table
---@return DotnetResult[]
function TestFrameworkBase.create_intermediate_results(test_results)
  ---@type DotnetResult[]
  local intermediate_results = {}

  local outcome_mapper = {
    Passed = "passed",
    Failed = "failed",
    Skipped = "skipped",
    NotExecuted = "skipped",
  }

  for _, value in pairs(test_results) do
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
function TestFrameworkBase.convert_intermediate_results(intermediate_results, test_nodes)
  local neotest_results = {}

  for _, intermediate_result in ipairs(intermediate_results) do
    for _, node in ipairs(test_nodes) do
      local node_data = node:data()

      if intermediate_result.test_name == node_data.full_name then
        -- For non-inlined parameterized tests, check if we already have an entry for the test.
        -- If so, we need to check for a failure, and ensure the entire group of tests is marked as failed.
        neotest_results[node_data.id] = neotest_results[node_data.id]
          or {
            status = intermediate_result.status,
            short = node_data.full_name .. ":" .. intermediate_result.status,
            errors = {},
          }

        if intermediate_result.status == "failed" then
          -- Mark as failed for the whole thing
          neotest_results[node_data.id].status = "failed"
          neotest_results[node_data.id].short = node_data.full_name .. ":failed"
        end

        if intermediate_result.error_info then
          table.insert(neotest_results[node_data.id].errors, {
            message = intermediate_result.test_name .. ": " .. intermediate_result.error_info,
          })

          -- Mark as failed
          neotest_results[node_data.id].status = "failed"
        end

        break
      end
    end
  end

  return neotest_results
end

return TestFrameworkBase
