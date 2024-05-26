local framework_discovery = require("neotest-dotnet.framework-discovery")

local M = {}

function M.get_queries(custom_attributes)
  -- Don't include parameterized test attribute indicators so we don't double count them
  local custom_fact_attributes = custom_attributes
      and framework_discovery.join_test_attributes(custom_attributes.xunit)
    or ""

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

return M
