rockspec_format = "3.0"
package = "neotest-dotnet"
version = "scm-1"

dependencies = {
  "lua >= 5.1",
  "neotest",
  "tree-sitter-fsharp",
  "tree-sitter-c_sharp",
}

test_dependencies = {
  "lua >= 5.1",
  "busted",
  "nlua",
}

source = {
  url = "git://github.com/issafalcon/neotest-dotnet",
}

build = {
  type = "builtin",
  copy_directories = {
    "scripts",
  },
}
