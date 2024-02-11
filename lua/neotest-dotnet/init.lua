local lib = require("neotest.lib")
local logger = require("neotest.logging")
local result_utils = require("neotest-dotnet.utils.result-utils")
local trx_utils = require("neotest-dotnet.utils.trx-utils")
local framework_base = require("neotest-dotnet.frameworks.test-framework-base")
local attribute = require("neotest-dotnet.frameworks.test-attributes")
local build_spec_utils = require("neotest-dotnet.utils.build-spec-utils")
local neotest_node_tree_utils = require("neotest-dotnet.utils.neotest-node-tree-utils")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }
local dap_args
local custom_attribute_args
local dotnet_additional_args
local discovery_root = "project"

DotnetNeotestAdapter.root = function(path)
  if discovery_root == "solution" then
    return lib.files.match_root_pattern("*.sln")(path)
  else
    return lib.files.match_root_pattern("*.csproj", "*.fsproj")(path)
  end
end

DotnetNeotestAdapter.is_test_file = function(file_path)
  if vim.endswith(file_path, ".cs") or vim.endswith(file_path, ".fs") then
    local content = lib.files.read(file_path)

    local found_derived_attribute
    local found_standard_test_attribute

    -- Combine all attribute list arrays into one
    local all_attributes = attribute.all_test_attributes

    for _, test_attribute in ipairs(all_attributes) do
      if string.find(content, "%[" .. test_attribute) then
        found_standard_test_attribute = true
        break
      end
    end

    if custom_attribute_args then
      for _, framework_attrs in pairs(custom_attribute_args) do
        for _, value in ipairs(framework_attrs) do
          if string.find(content, "%[" .. value) then
            found_derived_attribute = true
            break
          end
        end
      end
    end

    return found_standard_test_attribute or found_derived_attribute
  else
    return false
  end
end

DotnetNeotestAdapter.filter_dir = function(name)
  return name ~= "bin" and name ~= "obj"
end

DotnetNeotestAdapter._build_position = function(...)
  return framework_base.build_position(...)
end

DotnetNeotestAdapter._position_id = function(...)
  return framework_base.position_id(...)
end

---@param path any The path to the file to discover positions in
---@return neotest.Tree
DotnetNeotestAdapter.discover_positions = function(path)
  local content = lib.files.read(path)
  local test_framework = framework_base.get_test_framework_utils(content, custom_attribute_args)
  local framework_queries = test_framework.get_treesitter_queries(custom_attribute_args)

  local query = [[
    ;; --Namespaces
    ;; Matches namespace with a '.' in the name
    (namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition

    ;; Matches namespace with a single identifier (no '.')
    (namespace_declaration
        name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Matches file-scoped namespaces (qualified and unqualified respectively)
    (file_scoped_namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition

    (file_scoped_namespace_declaration
        name: (identifier) @namespace.name
    ) @namespace.definition
  ]] .. framework_queries

  local tree = lib.treesitter.parse_positions(path, query, {
    nested_namespaces = true,
    nested_tests = true,
    build_position = "require('neotest-dotnet')._build_position",
    position_id = "require('neotest-dotnet')._position_id",
  })

  logger.debug("neotest-dotnet: Original Position Tree: ")
  logger.debug(tree:to_list())

  local modified_tree = test_framework.post_process_tree_list(tree, path)

  logger.debug("neotest-dotnet: Post-processed Position Tree: ")
  logger.debug(modified_tree:to_list())

  return modified_tree
end

---@summary Neotest core interface method: Build specs for running tests
---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
DotnetNeotestAdapter.build_spec = function(args)
  logger.debug("neotest-dotnet: Creating specs from Tree (as list): ")
  logger.debug(args.tree:to_list())

  local additional_args = args.dotnet_additional_args or dotnet_additional_args or nil

  local specs = build_spec_utils.create_specs(args.tree, nil, additional_args)

  logger.debug("neotest-dotnet: Created " .. #specs .. " specs, with contents: ")
  logger.debug(specs)

  if args.strategy == "dap" then
    if #specs > 1 then
      logger.warn(
        "neotest-dotnet: DAP strategy does not support multiple test projects. Please debug test projects or individual tests. Falling back to using default strategy."
      )
      args.strategy = "integrated"
      return specs
    else
      specs[1].dap_args = dap_args
      specs[1].strategy = require("neotest-dotnet.strategies.netcoredbg")
    end
  end

  return specs
end

---@async
---@param spec neotest.RunSpec
---@param _ neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
DotnetNeotestAdapter.results = function(spec, _, tree)
  local output_file = spec.context.results_path

  logger.debug("neotest-dotnet: Fetching results from neotest tree (as list): ")
  logger.debug(tree:to_list())

  local test_nodes = neotest_node_tree_utils.get_test_nodes_data(tree)

  logger.debug("neotest-dotnet: Test Nodes: ")
  logger.debug(test_nodes)

  local parsed_data = trx_utils.parse_trx(output_file)
  local test_results = parsed_data.TestRun and parsed_data.TestRun.Results
  local test_definitions = parsed_data.TestRun and parsed_data.TestRun.TestDefinitions

  logger.debug("neotest-dotnet: TRX Results Output: ")
  logger.debug(test_results)

  logger.debug("neotest-dotnet: TRX Test Definitions Output: ")
  logger.debug(test_definitions)

  local intermediate_results

  if test_results and test_definitions then
    if #test_results.UnitTestResult > 1 then
      test_results = test_results.UnitTestResult
    end
    if #test_definitions.UnitTest > 1 then
      test_definitions = test_definitions.UnitTest
    end

    intermediate_results = result_utils.create_intermediate_results(test_results, test_definitions)
  end

  -- No test results. Something went wrong. Check for runtime error
  if not intermediate_results then
    return result_utils.get_runtime_error(spec.context.id)
  end

  logger.info(
    "neotest-dotnet: Found "
      .. #test_results
      .. " test results when parsing TRX file: "
      .. output_file
  )

  logger.debug("neotest-dotnet: Intermediate Results: ")
  logger.debug(intermediate_results)

  local neotest_results =
    result_utils.convert_intermediate_results(intermediate_results, test_nodes)

  logger.debug("neotest-dotnet: Neotest Results after conversion of Intermediate Results: ")
  logger.debug(neotest_results)

  return neotest_results
end

setmetatable(DotnetNeotestAdapter, {
  __call = function(_, opts)
    if type(opts.dap) == "table" then
      dap_args = opts.dap
    end
    if type(opts.custom_attributes) == "table" then
      custom_attribute_args = opts.custom_attributes
    end
    if type(opts.dotnet_additional_args) == "table" then
      dotnet_additional_args = opts.dotnet_additional_args
    end
    if type(opts.discovery_root) == "string" then
      discovery_root = opts.discovery_root
    end
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
