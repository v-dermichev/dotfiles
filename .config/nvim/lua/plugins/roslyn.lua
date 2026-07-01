return {
  "seblyng/roslyn.nvim",
  enabled = true,
  ft = "cs",
  -- Pre-fire (registered at startup via `init`, since `config` only runs once a
  -- .cs file lazy-loads the plugin — too late). A .cs document opened before the
  -- solution is loaded lands in roslyn's "miscellaneous files" workspace (no
  -- project references) → no inlay hints + false IDE0005. So when a folder
  -- containing a solution is opened, force-load roslyn and start it for that
  -- solution up front (without attaching to any buffer). By the time a .cs file
  -- is opened it reuses this warmed client and the document attaches to an
  -- already-loaded solution — hints from the first request, no restart needed.
  init = function()
    local prefired = {}
    local function prefire(base)
      base = (base and base ~= "") and base or vim.api.nvim_buf_get_name(0)
      if base == "" then base = vim.uv.cwd() end
      if not base then return end

      local found = vim.fs.find(function(name)
        return name:match("%.slnx?$") ~= nil or name:match("%.slnf$") ~= nil
      end, { upward = true, path = base, type = "file", limit = 1 })
      local file = found[1]
      if not file then return end

      local rootdir = vim.fs.dirname(file)
      if prefired[rootdir] then return end
      prefired[rootdir] = true

      -- Force-load the plugin so vim.lsp.config["roslyn"] and on_init exist.
      require("lazy").load({ plugins = { "roslyn.nvim" } })

      for _, c in ipairs(vim.lsp.get_clients({ name = "roslyn" })) do
        if c.config.root_dir == rootdir then return end
      end

      local cfg = vim.tbl_deep_extend("force", vim.lsp.config["roslyn"], {
        root_dir = rootdir,
        on_init = function(c)
          require("roslyn.lsp.on_init").sln(c, file)
        end,
      })
      vim.lsp.start(cfg, { attach = false })
    end

    vim.api.nvim_create_autocmd("VimEnter", { callback = function() prefire() end })
    vim.api.nvim_create_autocmd("DirChanged", { callback = function(a) prefire(a.file) end })
  end,
  config = function()
    vim.lsp.config("roslyn", {
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
    -- lock_target keeps the resolved solution for the session: roslyn.nvim's
    -- `BufEnter *.cs` handler otherwise re-derives the global solution from the
    -- current buffer's client, so landing on an octo diff buffer (no real
    -- client/solution) can overwrite it with nil and break resolution for the
    -- real files. With lock_target that BufEnter no longer mutates the global.
    require("roslyn").setup({ lock_target = true })
  end

}
