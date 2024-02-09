local logger = require("neotest.logging")
local lib = require("neotest.lib")
local DotnetUtils = require("neotest-dotnet.utils.dotnet-utils")
local types = require("neotest.types")
local node_tree_utils = require("neotest-dotnet.utils.neotest-node-tree-utils")
local Tree = types.Tree

---@class FrameworkUtils
---@field get_treesitter_queries function the TS queries for the framework
---@field build_parameterized_test_positions function Builds a tree of parameterized test nodes
---@field post_process_tree_list function Modifies the tree using supplementary information from dotnet test -t or other methods
local M = {}

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

  local function process_test_names(node_tree)
    for i, node in ipairs(node_tree) do
      if node.type == "test" then
        local matched_tests = {}
        local node_test_name = node.name

        -- If node.display_name is not nil, use it to match the test name
        if node.display_name ~= nil then
          node_test_name = node.display_name
        else
          node_test_name = node_tree_utils.get_qualified_test_name_from_id(node.id)
        end

        logger.debug("neotest-dotnet: Processing test name: " .. node_test_name)

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
          end

          logger.debug("testing: node_tree after parameterized tests: ")
          logger.debug(node_tree)
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
