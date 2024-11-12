return [[
    ;; Matches namespace with a '.' in the name
    (namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition

    ;; Matches namespace with a single identifier (no '.')
    (namespace_declaration
        name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Matches file-scoped namespaces (qualified and unqualified respectively)
    (file_scoped_namespace_declaration
        name: (qualified_name) @namespace.name
    ) @namespace.definition

    (file_scoped_namespace_declaration
        name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Matches XUnit test class (has no specific attributes on class)
    (class_declaration
      name: (identifier) @namespace.name
    ) @namespace.definition

    ;; Matches test methods
    (method_declaration
      name: (identifier) @test.name
    ) @test.definition
]]
