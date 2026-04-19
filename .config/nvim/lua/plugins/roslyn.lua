return {
  "seblyng/roslyn.nvim",
  enabled = true,
  ft = "cs",
  config = function()
    vim.lsp.config("roslyn", {
      on_attach = function()
        print("This will run when the server attaches!")
      end,
      settings = {
        ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types  = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types   = true,
            csharp_enable_inlay_hints_for_types                    = true,
            dotnet_enable_inlay_hints_for_parameters                 = true,
            dotnet_enable_inlay_hints_for_literal_parameters         = true,
            dotnet_enable_inlay_hints_for_indexer_parameters         = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters           = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = false,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent   = false,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name   = false,
        },
        ["csharp|code_lens"] = {
            dotnet_enable_references_code_lens = true,
        },
        ["csharp|background_analysis"] = {
            dotnet_analyzer_diagnostics_scope = "fullSolution",
            dotnet_compiler_diagnostics_scope = "fullSolution"
        },
        ["csharp|completion"] = {
            dotnet_show_completion_items_from_unimported_namespaces = true
        }
      },

    })
    require("roslyn").setup()
  end

}
