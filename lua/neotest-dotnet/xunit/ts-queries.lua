local framework_discovery = require("neotest-dotnet.framework-discovery")

local M = {}

local function get_fsharp_queries(custom_fact_attributes)
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
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "Fact" "ClassData" ]] .. custom_fact_attributes .. [[)))))
      (function_or_value_defn
        (function_declaration_left
          (identifier) @test.name))
    ) @test.definition

    ;; Matches test methods
    (member_defn
      (attributes
        (attribute
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "Fact" "ClassData" ]] .. custom_fact_attributes .. [[)))))
      (method_or_prop_defn
        (property_or_ident
           (identifier) @test.name .))
    ) @test.definition

    ;; Matches test parameterized function
    (declaration_expression
      (attributes
        (attribute
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "Theory")))))
      (function_or_value_defn
        (function_declaration_left
           (identifier) @test.name
           (argument_patterns) @parameter_list))
    ) @test.definition

    ;; Matches test parameterized methods
    (member_defn
      (attributes
        (attribute
          (simple_type (long_identifier (identifier) @attribute_name (#any-of? @attribute_name "Theory")))))
      (method_or_prop_defn
        (property_or_ident
           (identifier) @test.name .)
         args: (_) @parameter_list)
    ) @test.definition
  ]]
end

local function get_csharp_queries(custom_fact_attributes)
  return [[
    ;; Matches XUnit test class (has no specific attributes on class)
    (class_declaration
      name: (identifier) @class.name
    ) @class.definition

    ;; Matches test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "Fact" "ClassData" ]] .. custom_fact_attributes .. [[)
          (attribute_argument_list
            (attribute_argument
              (assignment_expression
                left: (identifier) @property_name (#match? @property_name "DisplayName$")
                right: (string_literal
                  (string_literal_content) @display_name
                )
              )
            )
          )?
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Specflow - XUnit
    (method_declaration
      (attribute_list
        (attribute
          name: (qualified_name) @attribute_name (#match? @attribute_name "SkippableFactAttribute$")
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Matches parameterized test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "Theory")
          (attribute_argument_list
            (attribute_argument
              (assignment_expression
                left: (identifier) @property_name (#match? @property_name "DisplayName$")
                right: (string_literal
                  (string_literal_content) @display_name
                )
              )
            )
          )*
        )
      )
      (attribute_list
        (attribute
          name: (identifier) @extra_attributes (#not-any-of? @extra_attributes "ClassData")
        )
      )*
      name: (identifier) @test.name
      parameters: (parameter_list
        (parameter
          name: (identifier)
        )*
      ) @parameter_list
    ) @test.definition
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
