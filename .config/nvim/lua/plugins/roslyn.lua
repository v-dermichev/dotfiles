return {
  "seblyng/roslyn.nvim",
  enabled = true,
  ft = "cs",
  -- Keep roslyn pointed at the solution that owns the current working context,
  -- so C# features are always backed by a loaded solution rather than roslyn's
  -- "miscellaneous files" workspace (no project references, meaning no inlay
  -- hints and false IDE0005).
  --
  -- Registered at startup via `init` (not `config`, which only runs once a .cs
  -- file lazy-loads the plugin, too late to warm anything). On VimEnter this
  -- warm-loads the solution nearest the cwd up front, so the first .cs document
  -- attaches to an already-loaded solution (hints from the first request). On
  -- DirChanged (the neo-tree `w` :cd, a project switch, ...) it re-targets: cd
  -- into a folder under a different solution switches to it; a cd within the
  -- same solution, or into one with none, does nothing (no teardown, no reload).
  --
  -- Switching is an explicit stop then start, NOT `:lsp restart`: restart reuses
  -- a client's already-resolved root_dir (see vim/lsp/client.lua Client:_restart)
  -- so it would only reload the same solution. This mirrors `:Roslyn target`,
  -- re-attaching every open C#/Razor buffer to a client on the new solution.
  init = function()
    local switching = false

    -- Upward-nearest .sln / .slnx / .slnf from `base` (a file or dir path).
    local function find_sln(base)
      base = (base and base ~= "") and base or vim.api.nvim_buf_get_name(0)
      if base == "" then base = vim.uv.cwd() end
      if not base then return nil end
      local found = vim.fs.find(function(name)
        return name:match("%.slnx?$") ~= nil or name:match("%.slnf$") ~= nil
      end, { upward = true, path = base, type = "file", limit = 1 })
      return found[1]
    end

    local function retarget(base)
      local file = find_sln(base)
      if not file then return end -- no solution above this path
      if file == vim.g.roslyn_nvim_selected_solution then return end -- already active
      if switching then return end

      -- Force-load the plugin so vim.lsp.config["roslyn"] and on_init exist.
      require("lazy").load({ plugins = { "roslyn.nvim" } })
      local rootdir = vim.fs.dirname(file)

      -- A client may already serve this solution while the global is momentarily
      -- unset (a warm start still initializing), so don't restart it.
      for _, c in ipairs(vim.lsp.get_clients({ name = "roslyn" })) do
        if c.config.root_dir == rootdir then return end
      end

      local cfg = vim.tbl_deep_extend("force", vim.lsp.config["roslyn"], {
        root_dir = rootdir,
        on_init = function(c)
          require("roslyn.lsp.on_init").sln(c, file)
        end,
      })

      -- Every loaded C#/Razor buffer should follow the new solution.
      local bufs = {}
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) then
          local ft = vim.bo[b].filetype
          if ft == "cs" or ft == "razor" then bufs[#bufs + 1] = b end
        end
      end

      local function start()
        switching = false
        if #bufs == 0 then
          vim.lsp.start(cfg, { attach = false })
        else
          for _, b in ipairs(bufs) do
            vim.lsp.start(cfg, { bufnr = b })
          end
        end
      end

      local clients = vim.lsp.get_clients({ name = "roslyn" })
      if #clients == 0 then
        start() -- nothing running yet: startup warm-load
        return
      end

      -- Stop the current server(s), then start the new one once they have
      -- actually exited. Roslyn can be slow to release, and starting before the
      -- old process is gone races the shutdown. Cap the wait so a stuck server
      -- cannot wedge the switch.
      switching = true
      local force = vim.uv.os_uname().sysname == "Windows_NT"
      for _, c in ipairs(clients) do
        c:stop(force)
      end
      local elapsed = 0
      local timer = assert(vim.uv.new_timer())
      timer:start(50, 50, vim.schedule_wrap(function()
        elapsed = elapsed + 50
        if #vim.lsp.get_clients({ name = "roslyn" }) == 0 or elapsed >= 10000 then
          timer:stop()
          timer:close()
          start()
        end
      end))
    end

    vim.api.nvim_create_autocmd("VimEnter", { callback = function() retarget() end })
    vim.api.nvim_create_autocmd("DirChanged", { callback = function(a) retarget(a.file) end })
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
