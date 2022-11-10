return [[
  ;; Matches test classes
  (class_declaration
    (attribute_list
      (attribute
        name: (identifier) @attribute_name (#any-of? @attribute_name "TestClass" "TestFixture")
      )
    )
    name: (identifier) @namespace.name
  ) @namespace.definition

  ;; Matches test methods
  (method_declaration
    (attribute_list
      (attribute
        name: (identifier) @attribute_name (#any-of? @attribute_name "TestMethod" "Test" "Fact")
      )
    )
    name: (identifier) @test.name
  ) @test.definition
]]
