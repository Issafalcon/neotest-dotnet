local logger = require("neotest.logging")
local lib = require("neotest.lib")
local DotnetUtils = require("neotest-dotnet.utils.dotnet-utils")
local BuildSpecUtils = require("neotest-dotnet.utils.build-spec-utils")
local types = require("neotest.types")
local NodeTreeUtils = require("neotest-dotnet.utils.neotest-node-tree-utils")
local TrxUtils = require("neotest-dotnet.utils.trx-utils")
local Tree = types.Tree

---@type FrameworkUtils
---@diagnostic disable-next-line: missing-fields
local M = {}

function M.get_treesitter_queries(custom_attribute_args)
  return require("neotest-dotnet.xunit.ts-queries").get_queries(custom_attribute_args)
end

local get_node_type = function(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
  end
  if captured_nodes["class.name"] then
    return "class"
  end
end

M.build_position = function(file_path, source, captured_nodes)
  local match_type = get_node_type(captured_nodes)

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
    framework = "xunit",
    is_class = is_class,
    display_name = display_name,
    path = file_path,
    name = name,
    range = { definition:range() },
  }

  return node
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

  return original_id
end

---Modifies the tree using supplementary information from dotnet test -t or other methods
---@param tree neotest.Tree The tree to modify
---@param path string The path to the file the tree was built from
M.post_process_tree_list = function(tree, path)
  local proj_root = lib.files.match_root_pattern("*.csproj")(path)
  local test_list_job = DotnetUtils.get_test_full_names(proj_root)
  local dotnet_tests = test_list_job.result().output
  local tree_as_list = tree:to_list()

  local short_name_pat = "%.([%w_]+)$"
  local short_name_only_pat = "%.([%w_]+)%(.*%)$"
  local short_name_with_param_pat = "%.([%w_]+%(.*%))$"

  local function process_test_names(node_tree)
    for _, node in ipairs(node_tree) do
      if node.type == "test" then
        local matched_tests = {}
        local node_test_name = node.name
        local running_id = node.id

        -- If node.display_name is not nil, use it to match the test name
        if node.display_name ~= nil then
          node_test_name = node.display_name
        else
          node_test_name = NodeTreeUtils.get_qualified_test_name_from_id(node.id)
        end

        logger.debug("neotest-dotnet: Processing test name: " .. node_test_name)

        for _, dotnet_name in ipairs(dotnet_tests) do
          -- First remove parameters from test name so we just match the "base" test name
          if string.find(dotnet_name:gsub("%b()", ""), node_test_name, 0, true) then
            table.insert(matched_tests, dotnet_name)
          end
        end

        if #matched_tests > 1 then
          -- This is a parameterized test (multiple matches for the same test)
          local parent_node_ranges = node.range
          for j, matched_name in ipairs(matched_tests) do
            local sub_id = path .. "::" .. string.gsub(matched_name, "%.", "::")
            local sub_test = {}
            local short_name = string.match(matched_name, short_name_with_param_pat)
            local sub_node = {
              id = sub_id,
              is_class = false,
              name = short_name,
              path = path,
              range = {
                parent_node_ranges[1] + j,
                parent_node_ranges[2],
                parent_node_ranges[1] + j,
                parent_node_ranges[4],
              },
              type = "test",
              framework = "xunit",
              running_id = running_id,
            }
            table.insert(sub_test, sub_node)
            table.insert(node_tree, sub_test)
          end

          local short_name = string.match(matched_tests[1], short_name_only_pat)
          node_tree[1] = vim.tbl_extend("force", node, {
            name = short_name,
            framework = "xunit",
            running_id = running_id,
          })

          logger.debug("testing: node_tree after parameterized tests: ")
          logger.debug(node_tree)
        elseif #matched_tests == 1 then
          logger.debug("testing: matched one test with name: " .. matched_tests[1])
          local short_name = string.match(matched_tests[1], short_name_pat)
          node_tree[1] = vim.tbl_extend(
            "force",
            node,
            { name = short_name, framework = "xunit", running_id = running_id }
          )
        end
      end

      process_test_names(node)
    end
  end

  process_test_names(tree_as_list)

  logger.debug("neotest-dotnet: Processed tree before leaving method: ")
  logger.debug(tree_as_list)

  return Tree.from_list(tree_as_list, function(pos)
    return pos.id
  end)
end

M.generate_test_results = function(output_file_path, tree, context_id)
  local parsed_data = TrxUtils.parse_trx(output_file_path)
  local test_results = parsed_data.TestRun and parsed_data.TestRun.Results
  local test_definitions = parsed_data.TestRun and parsed_data.TestRun.TestDefinitions

  logger.debug("neotest-dotnet: TRX Results Output for" .. output_file_path .. ": ")
  logger.debug(test_results)

  local test_nodes = NodeTreeUtils.get_test_nodes_data(tree)

  logger.debug("neotest-dotnet: xUnit test Nodes: ")
  logger.debug(test_nodes)

  local intermediate_results

  if test_results then
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
                -- For Specflow tests, the will be an inline DisplayName attribute.
                -- This wrecks the test name for us, so we need to use the ClassName and
                -- MethodName attributes to get the full test name to use when comparing the results with the node name.
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
          test_name = value._attr.testName,
          qualified_test_name = qualified_test_name,
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

      if
        intermediate_result.test_name == node_data.full_name
        or string.find(intermediate_result.test_name, node_data.full_name, 0, true)
        or intermediate_result.qualified_test_name == BuildSpecUtils.build_test_fqn(node_data.id)
      then
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

  logger.debug("neotest-dotnet: xUnit Neotest Results after conversion of Intermediate Results: ")
  logger.debug(neotest_results)

  return neotest_results
end

return M
