local logger = require("neotest.logging")
local TrxUtils = require("neotest-dotnet.utils.trx-utils")
local NodeTreeUtils = require("neotest-dotnet.utils.neotest-node-tree-utils")

---@type FrameworkUtils
---@diagnostic disable-next-line: missing-fields
local M = {}

---Builds a position from captured nodes, optionally parsing parameters to create sub-positions.
---@param base_node table The initial root node to build the positions from
---@param source any The source code to build the positions from
---@param captured_nodes any The nodes captured by the TS query
---@param match_type string The type of node that was matched by the TS query
---@return table
local build_parameterized_test_positions = function(base_node, source, captured_nodes, match_type)
  logger.debug("neotest-dotnet(NUnit Utils): Building parameterized test positions from source")
  logger.debug("neotest-dotnet(NUnit Utils): Base node: ")
  logger.debug(base_node)

  logger.debug("neotest-dotnet(NUnit Utils): Match Type: " .. match_type)

  local query = [[
    ;;query
    (attribute_list
      (attribute
        name: (identifier) @attribute_name (#any-of? @attribute_name "TestCase")
        ((attribute_argument_list) @arguments)
      )
    )
  ]]

  local param_query = vim.fn.has("nvim-0.9.0") == 1 and vim.treesitter.query.parse("c_sharp", query)
    or vim.treesitter.parse_query("c_sharp", query)

  -- Set type to test (otherwise it will be test.parameterized)
  local parameterized_test_node = vim.tbl_extend("force", base_node, { type = "test" })
  local nodes = { parameterized_test_node }

  -- Test method has parameters, so we need to create a sub-position for each test case
  local capture_indices = {}
  for i, capture in ipairs(param_query.captures) do
    capture_indices[capture] = i
  end
  local arguments_index = capture_indices["arguments"]

  for _, match in param_query:iter_matches(captured_nodes[match_type .. ".definition"], source) do
    local args_node = match[arguments_index]
    local args_text = vim.treesitter.get_node_text(args_node, source):gsub("[()]", "")

    nodes[#nodes + 1] = vim.tbl_extend("force", parameterized_test_node, {
      name = parameterized_test_node.name .. "(" .. args_text .. ")",
      range = { args_node:range() },
    })
  end

  logger.debug("neotest-dotnet(NUnit Utils): Built parameterized test positions: ")
  logger.debug(nodes)

  return nodes
end

local get_match_type = function(captured_nodes)
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

function M.get_treesitter_queries(custom_attribute_args)
  return require("neotest-dotnet.nunit.ts-queries").get_queries(custom_attribute_args)
end

M.build_position = function(file_path, source, captured_nodes)
  local match_type = get_match_type(captured_nodes)

  local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
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
    framework = "nunit",
    is_class = is_class,
    display_name = nil,
    path = file_path,
    name = name,
    range = { definition:range() },
  }

  if match_type and match_type ~= "test.parameterized" then
    return node
  end

  return build_parameterized_test_positions(node, source, captured_nodes, match_type)
end

M.position_id = function(position, parents)
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

---Modifies the tree using supplementary information from dotnet test -t or other methods
---@param tree neotest.Tree The tree to modify
---@param path string The path to the file the tree was built from
M.post_process_tree_list = function(tree, path)
  return tree
end

M.generate_test_results = function(output_file_path, tree, context_id)
  local parsed_data = TrxUtils.parse_trx(output_file_path)
  local test_results = parsed_data.TestRun and parsed_data.TestRun.Results
  local test_definitions = parsed_data.TestRun and parsed_data.TestRun.TestDefinitions

  logger.debug("neotest-dotnet: NUnit TRX Results Output for" .. output_file_path .. ": ")
  logger.debug(test_results)

  logger.debug("neotest-dotnet: NUnit TRX Test Definitions Output: ")
  logger.debug(test_definitions)

  local test_nodes = NodeTreeUtils.get_test_nodes_data(tree)

  logger.debug("neotest-dotnet: NUnit test Nodes: ")
  logger.debug(test_nodes)

  local intermediate_results

  if test_results and test_definitions then
    if #test_results.UnitTestResult > 1 then
      test_results = test_results.UnitTestResult
    end
    if #test_definitions.UnitTest > 1 then
      test_definitions = test_definitions.UnitTest
    end

    intermediate_results = {}

    local outcome_mapper = {
      Passed = "passed",
      Failed = "failed",
      Skipped = "skipped",
      NotExecuted = "skipped",
    }

    for _, value in pairs(test_results) do
      local qualified_test_name

      if value._attr.testId ~= nil then
        for _, test_definition in pairs(test_definitions) do
          if test_definition._attr.id ~= nil then
            if value._attr.testId == test_definition._attr.id then
              local dot_index = string.find(test_definition._attr.name, "%.")
              local bracket_index = string.find(test_definition._attr.name, "%(")
              if dot_index ~= nil and (bracket_index == nil or dot_index < bracket_index) then
                qualified_test_name = test_definition._attr.name
              else
                -- Fix for https://github.com/Issafalcon/neotest-dotnet/issues/79
                -- Modifying display name property on non-parameterized tests gives the 'name' attribute
                -- the value of the display name, so we need to use the TestMethod name instead
                if bracket_index == nil then
                  qualified_test_name = test_definition.TestMethod._attr.className
                    .. "."
                    .. test_definition.TestMethod._attr.name
                else
                  qualified_test_name = test_definition.TestMethod._attr.className
                    .. "."
                    .. test_definition._attr.name
                end
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
  end

  -- No test results. Something went wrong. Check for runtime error
  if not intermediate_results then
    local run_outcome = {}
    run_outcome[context_id] = {
      status = "failed",
    }
    return run_outcome
  end

  logger.debug("neotest-dotnet: Intermediate Results: ")
  logger.debug(intermediate_results)

  local neotest_results = {}

  for _, intermediate_result in ipairs(intermediate_results) do
    for _, node in ipairs(test_nodes) do
      local node_data = node:data()
      -- The test name from the trx file uses the namespace to fully qualify the test name
      local result_test_name = intermediate_result.test_name

      local is_dynamically_parameterized = #node:children() == 0
        and not string.find(node_data.name, "%(.*%)")

      if is_dynamically_parameterized then
        -- Remove dynamically generated arguments as they are not in node_data
        result_test_name = string.gsub(result_test_name, "%(.*%)", "")
      end

      -- Use the full_name of the test, including namespace
      local is_match = #result_test_name == #node_data.full_name
        or string.find(result_test_name, node_data.full_name, 0, true)

      if is_match then
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

  logger.debug("neotest-dotnet: NUnit Neotest Results after conversion of Intermediate Results: ")
  logger.debug(neotest_results)

  return neotest_results
end
return M
