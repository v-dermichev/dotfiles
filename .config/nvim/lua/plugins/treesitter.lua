-- nvim-treesitter v1.0 (`main` branch) API.
-- Docs: https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md
-- Requires Neovim 0.12+ and tree-sitter CLI.

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- upstream: "This plugin does not support lazy-loading."
  build = ":TSUpdate",
  config = function()
    -- `# language=<lang>` comment injection (registers the directive used by
    -- after/queries/python/injections.scm before any buffer parses).
    require("config.ts_inject").setup()

    local parsers = {
      "python", "c_sharp", "lua", "vim", "vimdoc",
      "json", "json5", "yaml", "toml", "ron", "xml",
      "css", "html", "javascript", "typescript", "tsx", "sql",
      "rust", "bash", "markdown", "markdown_inline",
      "query", "regex", "diff", "gitcommit", "git_rebase",
    }

    -- Non-blocking install (runs in background; does not freeze the UI).
    -- On first launch parsers appear as they finish compiling.
    pcall(function()
      require("nvim-treesitter").install(parsers)
    end)

    -- Highlight + indent aren't auto-started on `main`; enable per buffer.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local buf  = args.buf
        local ft   = args.match
        local lang = vim.treesitter.language.get_lang(ft) or ft
        if lang and pcall(vim.treesitter.language.add, lang) then
          pcall(vim.treesitter.start, buf, lang)
          -- Treesitter indentation needs an `indents` query. Use it only when the
          -- language ships one; otherwise indentexpr() returns 0 and <CR> drops to
          -- column 0. C-family languages without one (c_sharp) fall back to cindent.
          local cfamily = { c_sharp = true, c = true, cpp = true, java = true }
          if vim.treesitter.query.get(lang, "indents") then
            vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          elseif cfamily[lang] then
            vim.bo[buf].cindent = true
          end
        end
      end,
    })
  end,
}
