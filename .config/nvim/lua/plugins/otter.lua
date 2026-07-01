-- otter.nvim: real LSP (completion / diagnostics / hover) *inside* `# language=X`
-- injected code strings. It reads the treesitter injections from
-- lua/config/ts_inject.lua (our directive-set injection.language is picked up
-- via the LanguageTree's own children()), extracts each embedded region into a
-- hidden synced buffer, and attaches that language's LSP.
return {
  "jmbuhr/otter.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  ft = { "python" },
  opts = {},
  config = function(_, opts)
    require("otter").setup(opts)

    -- Embedded languages to surface LSP for inside `# language=<lang>` strings.
    local langs = { "javascript", "sql", "json", "bash" }
    local function activate()
      -- Deferred so treesitter has started/parsed (FileType order). activate()
      -- is idempotent: it reuses the running otter-ls and existing hidden
      -- buffers, only creating one when a *new* language region appears — so
      -- re-running it on edits is how a freshly typed `# language=<lang>` gets
      -- its LSP without a restart.
      vim.schedule(function()
        pcall(require("otter").activate, langs, true, true, nil)
      end)
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "python",
      callback = function(args)
        activate()
        vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
          buffer = args.buf,
          callback = activate,
        })
      end,
    })
    if vim.bo.filetype == "python" then activate() end -- current buffer on lazy-load
  end,
}
