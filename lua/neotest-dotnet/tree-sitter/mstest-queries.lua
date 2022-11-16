return [[
    ;; Matches test classes
    (class_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#eq? @attribute_name "TestClass")
        )
      )
      name: (identifier) @namespace.name
    ) @namespace.definition

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
