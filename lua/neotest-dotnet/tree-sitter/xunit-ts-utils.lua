
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

  ;; Matches XUnit test class (has no specific attributes on class)
  (
    (using_directive
      (identifier) @package_name (#eq? @package_name "Xunit")
    )
    (namespace_declaration
      body: (declaration_list
        (class_declaration
          name: (identifier) @namespace.name
        ) @namespace.definition
      )
    )
  )

  ;; Matches parameterized test methods
  (method_declaration
    (attribute_list
      (attribute
        name: (identifier) @attribute_name (#any-of? @attribute_name "Theory" "InlineData")
      )
    )
    name: (identifier) @test.name
  ) @test.definition
]]
