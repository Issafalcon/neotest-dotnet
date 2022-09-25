local specflow_queries = require("neotest-dotnet.tree-sitter.specflow-queries")
local unit_test_queries = require("neotest-dotnet.tree-sitter.unit-test-queries")

local M = {}

local function get_parameterized_test_params(method)
  local params = {}
  for param in string.gmatch(method.parameters:gsub("[()]", ""), "([^,]+)") do
    -- Split string on whitespace separator and take last element (the param name)
    local type_identifier_split = vim.split(param, "%s")
    table.insert(params, type_identifier_split[#type_identifier_split])
  end

  return params
end

local function get_test_case_arguments(test_case)
  local args = {}
  for arg in string.gmatch(test_case.arguments:gsub("[()]", ""), "([^, ]+)") do
    table.insert(args, arg)
  end

  return args
end

M.test_case_prefix = "TestCase"

M.get_treesitter_test_query = function()
  return unit_test_queries
      .. specflow_queries
      .. [[
    ;; Matches XUnit test class (has no specific attributes on class)
    (
      (using_directive
        (identifier) @package_name (#eq? @package_name "Xunit")
      )
      (namespace_declaration
        body: (declaration_list
          (class_declaration
            name: (identifier) @namespace.name
          ) @namespace.definition
        )
      )
    )

    ;; Matches parameterized test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "Theory")
        )
      )
      name: (identifier) @test.parameterized.name
      parameters: (parameter_list
        (parameter
          name: (identifier)
        )*
      ) @parameter_list
    ) @test.parameterized.definition

    ;; Matches the individual test cases
    (attribute
      name: (identifier) @attribute_name (#any-of? @attribute_name "InlineData")
      (attribute_argument_list
        (attribute_argument)*
      ) @argument_list
    ) @test_case
  ]]
end

local function get_match_type(captured_nodes)
  if captured_nodes["test.name"] then
    return "test"
  end
  if captured_nodes["namespace.name"] then
    return "namespace"
  end
  if captured_nodes["test.parameterized.name"] then
    return "test.parameterized"
  end
end

---Returns a build position and captures any metadata regarding paraterized tests
---needed for further processing of the test cases
---@param file_path any
---@param source any
---@param captured_nodes any
---@param parameterized_methods ParameterizedTestMethod[] Storage table to keep track of parameterized test methods in order to process them later
---@param test_cases ParameterizedTestCase[] Storage table to keep track of parameterized test cases in order to process them later
---@return table
M.build_position = function(file_path, source, captured_nodes, parameterized_methods, test_cases)
  local match_type = get_match_type(captured_nodes)
  if match_type and match_type ~= "test.parameterized" then
    local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
    local definition = captured_nodes[match_type .. ".definition"]

    return {
      type = match_type,
      path = file_path,
      name = name,
      range = { definition:range() },
    }
  elseif match_type == "test.parameterized" then
    local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
    local definition = captured_nodes[match_type .. ".definition"]

    parameterized_methods[name] = {
      name = name,
      range = { definition:range() },
      parameters = vim.treesitter.get_node_text(captured_nodes["parameter_list"], source),
    }

    return {
      type = "test",
      path = file_path,
      name = name,
      range = { definition:range() },
    }
  elseif captured_nodes["test_case"] then
    -- For test_cases, don't actually add them to the tree yet. Keep track so we can
    -- first modify their test names and add them as children under the correct root test function.
    local test_definition = captured_nodes["test_case"]
    local test_arguments = vim.treesitter.get_node_text(captured_nodes["argument_list"], source)
    local test_name = M.test_case_prefix .. test_arguments

    table.insert(test_cases, {
      name = test_name,
      range = { test_definition:range() },
      arguments = test_arguments,
    })
  end
end

---Uses the parameterized test methods and test cases to build the final test tree for each parameterized test
---@param parameterized_methods ParameterizedTestMethod[]
---@param test_cases ParameterizedTestCase[]
---@param test_nodes neotest.Tree[]
---@return ReplacementParameterizedTestNode[]
M.create_replacement_parameterized_test_node = function(parameterized_methods, test_cases, test_nodes)
  ---@class ReplacementParameterizedTestNode
  ---@field node_key string The key of the node to be replaced
  ---@filed new_node neotest.Tree The replacement node

  ---@type ReplacementParameterizedTestNode[]
  local replacement_nodes = {}

  for _, node in ipairs(test_nodes) do
    local node_data = node:data()
    local method = parameterized_methods[node_data.name]
    if method then
      local new_node = {
        {
          type = "test",
          path = node_data.path,
          name = node_data.name,
          range = node_data.range,
          id = node_data.id,
        },
      }

      local id_segments = {}
      for segment in string.gmatch(node_data.id, "([^::]+)") do
        table.insert(id_segments, segment)
      end

      table.remove(id_segments, #id_segments)

      local method_params = get_parameterized_test_params(method)
      for _, case in ipairs(test_cases) do
        -- Check the test case is in range of the parameterized test method
        if method.range[1] < case.range[1] and method.range[3] > case.range[3] then
          local arguments = get_test_case_arguments(case)
          local param_pairs = ""
          for i, param in ipairs(method_params) do
            param_pairs = param_pairs .. param .. ": " .. arguments[i]
            if i ~= #method_params then
              param_pairs = param_pairs .. ", "
            end
          end

          local test_name = node_data.name .. "(" .. param_pairs .. ")"
          table.insert(new_node, {
            type = "test",
            path = node_data.path,
            name = test_name,
            range = case.range,
            id = table.concat(id_segments, "::") .. "::" .. test_name,
          })
        end
      end

      table.insert(replacement_nodes, {
        node_key = node._key,
        new_node = new_node,
      })
    end
  end

  return replacement_nodes
end
return M
