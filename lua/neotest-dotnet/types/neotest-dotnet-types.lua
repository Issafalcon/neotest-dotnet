---@meta

---@class DotnetResult[]
---@field status string
---@field raw_output string
---@field test_name string
---@field error_info string

---@class FrameworkUtils
---@field get_treesitter_queries fun(custom_attribute_args: any): string Gets the TS queries for the framework
---@field build_position fun(file_path: string, source: any, captured_nodes: any): any Builds a position from captured nodes
---@field position_id fun(position: any, parents: any): string Creates the id for a position based on the position node and parents
---@field post_process_tree_list fun(tree: neotest.Tree, path: string): neotest.Tree Post processes the tree list after initial position discovery
---@field generate_test_results fun(output_file_path: string, tree: neotest.Tree, context_id: string): neotest.Result[] Generates test results from trx results
