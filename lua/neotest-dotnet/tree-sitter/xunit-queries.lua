return [[
    ;; query
    ;; Matches XUnit test class (has no specific attributes on class)
    (
      (using_directive
        (identifier) @package_name (#eq? @package_name "Xunit")
      )
      [
        (namespace_declaration
          body: (declaration_list
            (class_declaration
              name: (identifier) @namespace.name
            ) @namespace.definition
          )
        )
        (file_scoped_namespace_declaration
          (class_declaration
            name: (identifier) @namespace.name
          ) @namespace.definition
        )
      ]
    )

    ;; Matches Xunit test class where using statement under namespace
    (
      [
        (namespace_declaration
          body: (declaration_list
            (using_directive
              (identifier) @package_name (#eq? @package_name "Xunit")
            )
            (class_declaration
              name: (identifier) @namespace.name
            ) @namespace.definition
          )
        )
        (file_scoped_namespace_declaration
          (using_directive
            (identifier) @package_name (#eq? @package_name "Xunit")
          )
          (class_declaration
            name: (identifier) @namespace.name
          ) @namespace.definition
        )
      ]
    )

    ;; Matches parameterized test methods
    (method_declaration
      (attribute_list
        (attribute
          name: (identifier) @attribute_name (#any-of? @attribute_name "Theory")
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
