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

    ;; Specflow - XUnit
    (method_declaration
      (attribute_list
        (attribute
          name: (qualified_name) @attribute_name (#match? @attribute_name "SkippableFactAttribute$")
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Specflow - NUnit
    (method_declaration
      (attribute_list
        (attribute
          name: (qualified_name) @attribute_name (#match? @attribute_name "TestAttribute$")
        )
      )
      name: (identifier) @test.name
    ) @test.definition

    ;; Specflow - MSTest
    (method_declaration
      (attribute_list
        (attribute
          name: (qualified_name) @attribute_name (#match? @attribute_name "TestMethodAttribute$")
        )
      )
      name: (identifier) @test.name
    ) @test.definition
]]
