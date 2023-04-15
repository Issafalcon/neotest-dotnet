local lib = require("neotest.lib")
local logger = require("neotest.logging")
local async = require("neotest.async")
local result_utils = require("neotest-dotnet.result-utils")
local trx_utils = require("neotest-dotnet.trx-utils")
local dap_utils = require("neotest-dotnet.dap-utils")
local framework_utils = require("neotest-dotnet.frameworks.test-framework-utils")
local attribute_utils = require("neotest-dotnet.frameworks.test-attribute-utils")
local build_spec_utils = require("neotest-dotnet.build-spec-utils")
local neotest_node_tree_utils = require("neotest-dotnet.neotest-node-tree-utils")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }
local dap_args
local custom_attribute_args
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
    local all_attributes = attribute_utils.all_test_attributes

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
  return framework_utils.build_position(...)
end

DotnetNeotestAdapter._position_id = function(...)
  return framework_utils.position_id(...)
end

--- Implementation of core neotest function.
---@param path any
---@return neotest.Tree
DotnetNeotestAdapter.discover_positions = function(path)
  local content = lib.files.read(path)
  local test_framework = framework_utils.get_test_framework_utils(content, custom_attribute_args)
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

  return tree
end

---@summary Neotest core interface method: Build specs for running tests
---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
DotnetNeotestAdapter.build_spec = function(args)
  logger.debug("neotest-dotnet: Creating specs from Tree (as list): ")
  logger.debug(args.tree:to_list())

  local specs = build_spec_utils.create_specs(args.tree)

  logger.debug("neotest-dotnet: Created " .. #specs .. " specs, with contents: ")
  logger.debug(specs)

  if args.strategy == "dap" then
    if #specs > 1 then
      logger.warn(
        "neotest-dotnet: DAP strategy does not support multiple test projects. Please debug test projects or individual tests. Falling back to using default strategy."
      )
      return specs
    else
      local spec = specs[1]
      local debug_future = async.control.future()
      logger.info("neotest-dotnet: Running tests in debug mode")

      dap_utils.start_debuggable_test(spec.command, function(dotnet_test_pid)
        spec.strategy = dap_utils.get_dap_adapter_config(dotnet_test_pid, dap_args)
        spec.command = nil
        logger.info("neotest-dotnet: Sending debug start")
        debug_future.set()
      end)

      debug_future.wait()
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
    if type(opts.discovery_root) == "string" then
      discovery_root = opts.discovery_root
    end
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
