local framework_discovery = require("neotest-dotnet.framework-discovery")

local M = {}

function M.get_queries(custom_attributes)
  -- Don't include parameterized test attribute indicators so we don't double count them
  local custom_fact_attributes = custom_attributes
      and framework_discovery.join_test_attributes(custom_attributes.mstest)
    or ""

  return [[
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
      name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Specflow - MSTest
    (method_declaration
      (attribute_list
        (attribute
          name: (qualified_name) @attribute_name (#match? @attribute_name "TestMethodAttribute$")
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Matches test classes
    (class_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#eq? @attribute_name "TestClass")
        )
      )
      name: (identifier) @class.name
    ) @class.definition

    ;; Matches test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#eq? @attribute_name "TestMethod")
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Matches parameterized test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "DataTestMethod")
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

return M
