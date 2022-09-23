local async = require("neotest.async")
local lib = require("neotest.lib")
local specflow_queries = require("neotest-dotnet.tree-sitter.specflow-queries")
local unit_test_queries = require("neotest-dotnet.tree-sitter.unit-test-queries")

local M = {}

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
  ]]
end

-- Split out into separate attribute and method queries
M.get_parameterized_test_query = function()
  return [[
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

M.extract_test_cases = function(file_path, source, captured_nodes, parameterized_methods)
  if captured_nodes["test_case"] then
    local test_definition = captured_nodes["test_case"]
    local test_arguments = vim.treesitter.get_node_text(captured_nodes["argument_list"], source)
    local test_case_start, _, test_case_end, _ = test_definition:range()

    for name, method in pairs(parameterized_methods) do
      if method.range[1] < test_case_start and method.range[3] > test_case_end then
        local test_name = name .. "(" .. test_arguments .. ")"

        table.insert(parameterized_methods[name].nested_tests, {
          name = test_name,
          range = { test_definition:range() },
          file_path = file_path,
        })
      end
    end
  end
end

M.build_position_and_extract_parameterized = function(file_path, source, captured_nodes, cb)
  local match_type = get_match_type(captured_nodes)
  if match_type and match_type ~= "test.parameterized" then
    ---@type string
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

    -- Use callback to keep track of all the tests that are parameterized
    cb({
      name = name,
      parameter_list = vim.treesitter.get_node_text(captured_nodes["parameter_list"], source),
      nested_tests = {},
      range = { definition:range() },
    })

    return {
      type = "test",
      path = file_path,
      name = name,
      range = { definition:range() },
    }
  end
end

M.create_replacement_parameterized_test_node = function(parameterized_methods, test_nodes)
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

      for _, case in ipairs(method.nested_tests) do
        table.insert(new_node, {
          type = "test",
          path = case.file_path,
          name = case.name,
          range = case.range,
          id = table.concat(id_segments, "::") .. "::" .. case.name,
        })
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
