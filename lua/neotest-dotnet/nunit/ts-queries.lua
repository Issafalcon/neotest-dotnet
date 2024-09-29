local framework_discovery = require("neotest-dotnet.framework-discovery")

local M = {}

local function get_fsharp_queries(custom_test_attributes)
  return [[
    ;; Matches XUnit test class (has no specific attributes on class)
    (anon_type_defn
       (type_name (identifier) @class.name)
    ) @class.definition

    (named_module
        name: (long_identifier) @class.name
    ) @class.definition

    (module_defn
        (identifier) @class.name
    ) @class.definition

    ;; Matches test functions
    (declaration_expression
      (attributes
        (attribute
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "Test" "TestCaseSource" ]] .. custom_test_attributes .. [[)))))
      (function_or_value_defn
        (function_declaration_left
          (identifier) @test.name))
    ) @test.definition

    ;; Matches test methods
    (member_defn
      (attributes
        (attribute
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "Test" "TestCaseSource" ]] .. custom_test_attributes .. [[)))))
      (method_or_prop_defn
        (property_or_ident
           (identifier) @test.name .))
    ) @test.definition

    ;; Matches test parameterized function
    (declaration_expression
      (attributes
        (attribute
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "^TestCase")))))
      (function_or_value_defn
        (function_declaration_left
           (identifier) @test.name
           (argument_patterns) @parameter_list))
    ) @test.definition

    ;; Matches test parameterized methods
    (member_defn
      (attributes
        (attribute
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "^TestCase")))))
      (method_or_prop_defn
        (property_or_ident
           (identifier) @test.name .)
         args: (_) @parameter_list)
    ) @test.definition
  ]]
end

local function get_csharp_queries(custom_test_attributes)
  return [[
    ;; Wrap this in alternation (https://tree-sitter.github.io/tree-sitter/using-parsers#query-syntax)
    ;; otherwise Specflow generated classes will be picked up twice
    [
      ;; Matches SpecFlow generated classes
      (class_declaration
        (attribute_list
          (attribute 
            (attribute_argument_list
              (attribute_argument
                (string_literal) @attribute_argument (#match? @attribute_argument "SpecFlow\"$")
              )
            )
          )
        ) 
        name: (identifier) @class.name
      ) @class.definition

      ;; Matches test classes
      (class_declaration
        name: (identifier) @class.name
      ) @class.definition
    ]

    ;; Specflow - NUnit
    (method_declaration
      (attribute_list
        (attribute
          name: (qualified_name) @attribute_name (#match? @attribute_name "TestAttribute$")
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Matches test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#eq? @attribute_name "Test" "TestCaseSource" ]] .. custom_test_attributes .. [[)
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Matches parameterized test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#match? @attribute_name "^TestCase")
        )
      )+
      name: (identifier) @test.parameterized.name
      parameters: (parameter_list
        (parameter
          name: (identifier)
        )*
      ) @parameter_list
    ) @test.parameterized.definition
  ]]
end

function M.get_queries(lang, custom_attributes)
  -- Don't include parameterized test attribute indicators so we don't double count them
  local custom_fact_attributes = custom_attributes
      and framework_discovery.join_test_attributes(custom_attributes.xunit)
    or ""

  return lang == "fsharp" and get_fsharp_queries(custom_fact_attributes)
    or get_csharp_queries(custom_fact_attributes)
end

return M
