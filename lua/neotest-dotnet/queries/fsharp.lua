return [[
    (namespace
        name: (long_identifier) @namespace.name
    ) @namespace.definition

    (anon_type_defn
       (type_name (identifier) @namespace.name)
    ) @namespace.definition

    (named_module
        name: (long_identifier) @namespace.name
    ) @namespace.definition

    (module_defn
        (identifier) @namespace.name
    ) @namespace.definition

    (declaration_expression
      (function_or_value_defn
        (function_declaration_left . (_) @test.name))
    ) @test.definition

    (member_defn
      (method_or_prop_defn
        (property_or_ident
           (identifier) @test.name .))
    ) @test.definition
]]
