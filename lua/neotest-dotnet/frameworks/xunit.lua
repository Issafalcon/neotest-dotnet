local logger = require("neotest.logging")
local lib = require("neotest.lib")
local DotnetUtils = require("neotest-dotnet.utils.dotnet-utils")
local types = require("neotest.types")
local Tree = types.Tree

---@class FrameworkUtils
---@field get_treesitter_queries function the TS queries for the framework
---@field build_parameterized_test_positions function Builds a tree of parameterized test nodes
---@field post_process_tree_list function Modifies the tree using supplementary information from dotnet test -t or other methods
local M = {}

local function parameter_string_to_table(parameter_string)
  local params = {}
  for param in string.gmatch(parameter_string:gsub("[()]", ""), "([^,]+)") do
    -- Split string on whitespace separator and take last element (the param name)
    local type_identifier_split = vim.split(param, "%s")
    table.insert(params, type_identifier_split[#type_identifier_split])
  end

  return params
end

local function argument_string_to_table(arg_string)
  local args = {}
  for arg in string.gmatch(arg_string:gsub("[()]", ""), "([^, ]+)") do
    table.insert(args, arg)
  end

  return args
end

function M.get_treesitter_queries(custom_attribute_args)
  return require("neotest-dotnet.tree-sitter.xunit-queries").get_queries(custom_attribute_args)
end

---Builds a position from captured nodes, optionally parsing parameters to create sub-positions.
---@param base_node table The initial root node to build the positions from
---@param source any The source code to build the positions from
---@param captured_nodes any The nodes captured by the TS query
---@param match_type string The type of node that was matched by the TS query
---@return table
M.build_parameterized_test_positions = function(base_node, source, captured_nodes, match_type)
  -- logger.debug("neotest-dotnet(X-Unit Utils): Building parameterized test positions from source")
  -- logger.debug("neotest-dotnet(X-Unit Utils): Base node: ")
  -- logger.debug(base_node)
  --
  -- logger.debug("neotest-dotnet(X-Unit Utils): Match Type: " .. match_type)
  --
  -- local query = [[
  --     ;;query
  --     (attribute_list
  --       (attribute
  --         name: (identifier) @attribute_name (#any-of? @attribute_name "InlineData")
  --         ((attribute_argument_list) @arguments)
  --       )
  --     )
  --   ]]
  --
  -- local param_query = vim.fn.has("nvim-0.9.0") == 1 and vim.treesitter.query.parse("c_sharp", query)
  --   or vim.treesitter.parse_query("c_sharp", query)
  --
  -- -- Set type to test (otherwise it will be test.parameterized)
  -- local parameterized_test_node = vim.tbl_extend("force", base_node, { type = "test" })
  -- local nodes = { parameterized_test_node }
  --
  -- -- Test method has parameters, so we need to create a sub-position for each test case
  -- local capture_indices = {}
  -- for i, capture in ipairs(param_query.captures) do
  --   capture_indices[capture] = i
  -- end
  -- local arguments_index = capture_indices["arguments"]
  --
  -- for _, match in param_query:iter_matches(captured_nodes[match_type .. ".definition"], source) do
  --   local params_text = vim.treesitter.get_node_text(captured_nodes["parameter_list"], source)
  --   local args_node = match[arguments_index]
  --   local args_text = vim.treesitter.get_node_text(args_node, source)
  --   local params_table = parameter_string_to_table(params_text)
  --   local args_table = argument_string_to_table(args_text)
  --
  --   local named_params = ""
  --   for i, param in ipairs(params_table) do
  --     named_params = named_params .. param .. ": " .. args_table[i]
  --     if i ~= #params_table then
  --       named_params = named_params .. ", "
  --     end
  --   end
  --
  --   nodes[#nodes + 1] = vim.tbl_extend("force", parameterized_test_node, {
  --     name = parameterized_test_node.name .. "(" .. named_params .. ")",
  --     range = { args_node:range() },
  --   })
  -- end
  --
  -- logger.debug("neotest-dotnet(X-Unit Utils): Built parameterized test positions: ")
  -- logger.debug(nodes)

  return base_node
end

---Modifies the tree using supplementary information from dotnet test -t or other methods
---@param tree neotest.Tree The tree to modify
---@param path string The path to the file the tree was built from
M.post_process_tree_list = function(tree, path)
  local proj_root = lib.files.match_root_pattern("*.csproj")(path)
  local test_list_job = DotnetUtils.get_test_full_names(proj_root)
  local dotnet_tests = test_list_job.result().output
  local tree_as_list = tree:to_list()
  -- local processed_tests = {}

  local function process_test_names(node_tree)
    for i, node in ipairs(node_tree) do
      if
        node.type == "test"
        -- and processed_tests[node.id] == nil
        -- and processed_tests[node.name] == nil
      then
        local matched_tests = {}

        logger.debug("neotest-dotnet: Processing test name: " .. node.id)

        -- Find positions first match of '::' in value.id
        local _, start = string.find(node.id, "::")
        local node_test_name = string.sub(node.id, (start or 0) + 1)

        -- Replace all :: with . in node_test_name
        node_test_name = string.gsub(node_test_name, "::", ".")

        for _, dotnet_name in ipairs(dotnet_tests) do
          if string.find(dotnet_name, node_test_name, 0, true) then
            table.insert(matched_tests, dotnet_name)
          end
        end

        if #matched_tests > 1 then
          -- This is a parameterized test (multiple matches for the same test)
          local parent_node_ranges = node.range
          for j, matched_name in ipairs(matched_tests) do
            local sub_id = path .. "::" .. string.gsub(matched_name, "%.", "::")
            local sub_test = {}
            local sub_node = {
              id = sub_id,
              is_class = false,
              name = matched_name,
              path = path,
              range = {
                parent_node_ranges[1] + j,
                parent_node_ranges[2],
                parent_node_ranges[1] + j,
                parent_node_ranges[4],
              },
              type = "test",
            }
            table.insert(sub_test, sub_node)
            table.insert(node_tree, sub_test)
            -- table.insert(processed_tests, matched_name)
          end

          logger.debug("testing: node_tree after parameterized tests: ")
          logger.debug(node_tree)

          -- table.insert(node_tree, i + 1, parameterized_tests)
        elseif #matched_tests == 1 then
          -- Replace the name with the fully qualified test name
          node_tree[i] = vim.tbl_extend("force", node, { name = matched_tests[1] })
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

return M
