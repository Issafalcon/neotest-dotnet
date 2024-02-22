local framework_discovery = require("neotest-dotnet.framework-discovery")

local M = {}

function M.get_queries(custom_attributes)
  -- Don't include parameterized test attribute indicators so we don't double count them
  local custom_test_attributes = custom_attributes
      and framework_discovery.join_test_attributes(custom_attributes.nunit)
    or ""

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

return M
