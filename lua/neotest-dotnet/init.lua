local lib = require("neotest.lib")
local logger = require("neotest.logging")
local FrameworkDiscovery = require("neotest-dotnet.framework-discovery")
local build_spec_utils = require("neotest-dotnet.utils.build-spec-utils")

local DotnetNeotestAdapter = { name = "neotest-dotnet" }
local dap = { adapter_name = "netcoredbg" }
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
    local all_attributes = FrameworkDiscovery.all_test_attributes

    for _, test_attribute in ipairs(all_attributes) do
      if string.find(content, "%[<?" .. test_attribute) then
        found_standard_test_attribute = true
        break
      end
    end

    if custom_attribute_args then
      for _, framework_attrs in pairs(custom_attribute_args) do
        for _, value in ipairs(framework_attrs) do
          if string.find(content, "%[<?" .. value) then
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
  local args = { ... }

  logger.debug("neotest-dotnet: Buil Position Args: ")
  logger.debug(args)

  local framework =
    FrameworkDiscovery.get_test_framework_utils_from_source(args[2], custom_attribute_args) -- args[2] is the content of the file

  logger.debug("neotest-dotnet: Framework: ")
  logger.debug(framework)

  return framework.build_position(...)
end

DotnetNeotestAdapter._position_id = function(...)
  local args = { ... }
  local framework = args[1].framework and require("neotest-dotnet." .. args[1].framework)
    or require("neotest-dotnet.xunit")
  return framework.position_id(...)
end

---@param path any The path to the file to discover positions in
---@return neotest.Tree
DotnetNeotestAdapter.discover_positions = function(path)
  local lang = nil

  if lib.files.match_root_pattern("*.fsproj")(path) then
    lang = "fsharp"
  else
    lang = "c_sharp"
  end

  local content = lib.files.read(path)
  local test_framework =
    FrameworkDiscovery.get_test_framework_utils_from_source(lang, content, custom_attribute_args)
  local framework_queries = test_framework.get_treesitter_queries(lang, custom_attribute_args)

  -- local query = [[
  --   ;; --Namespaces
  --   ;; Matches namespace with a '.' in the name
  --   (namespace_declaration
  --       name: (qualified_name) @namespace.name
  --   ) @namespace.definition
  --
  --   ;; Matches namespace with a single identifier (no '.')
  --   (namespace_declaration
  --       name: (identifier) @namespace.name
  --   ) @namespace.definition
  --
  --   ;; Matches file-scoped namespaces (qualified and unqualified respectively)
  --   (file_scoped_namespace_declaration
  --       name: (qualified_name) @namespace.name
  --   ) @namespace.definition
  --
  --   (file_scoped_namespace_declaration
  --       name: (identifier) @namespace.name
  --   ) @namespace.definition
  -- ]] .. framework_queries
  local query = framework_queries

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
      specs[1].dap = dap
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

  local test_framework = FrameworkDiscovery.get_test_framework_utils_from_tree(tree)
  local results = test_framework.generate_test_results(output_file, tree, spec.context.id)

  return results
end

setmetatable(DotnetNeotestAdapter, {
  __call = function(_, opts)
    if type(opts.dap) == "table" then
      for k, v in pairs(opts.dap) do
        dap[k] = v
      end
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

    local function find_runsettings_files()
      local files = {}
      for _, runsettingsFile in
        ipairs(vim.fn.glob(vim.fn.getcwd() .. "**/*.runsettings", false, true))
      do
        table.insert(files, runsettingsFile)
      end

      for _, runsettingsFile in
        ipairs(vim.fn.glob(vim.fn.getcwd() .. "**/.runsettings", false, true))
      do
        table.insert(files, runsettingsFile)
      end

      return files
    end

    local function select_runsettings_file()
      local files = find_runsettings_files()
      if #files == 0 then
        print("No .runsettings files found")
        vim.g.neotest_dotnet_runsettings_path = nil
        return
      end

      vim.ui.select(files, {
        prompt = "Select runsettings file:",
        format_item = function(item)
          return vim.fn.fnamemodify(item, ":p:.")
        end,
      }, function(choice)
        if choice then
          vim.g.neotest_dotnet_runsettings_path = choice
          print("Selected runsettings file: " .. choice)
        end
      end)
    end

    vim.api.nvim_create_user_command("NeotestSelectRunsettingsFile", select_runsettings_file, {})
    vim.api.nvim_create_user_command("NeotestClearRunsettings", function()
      vim.g.neotest_dotnet_runsettings_path = nil
    end, {})
    return DotnetNeotestAdapter
  end,
})

return DotnetNeotestAdapter
