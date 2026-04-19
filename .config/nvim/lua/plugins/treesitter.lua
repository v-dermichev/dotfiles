-- nvim-treesitter v1.0 (`main` branch) API.
-- Docs: https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md
-- Requires Neovim 0.12+ and tree-sitter CLI.

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- upstream: "This plugin does not support lazy-loading."
  build = ":TSUpdate",
  config = function()
    local parsers = {
      "python", "c_sharp", "lua", "vim", "vimdoc",
      "json", "json5", "yaml", "toml", "ron",
      "css", "html", "javascript", "typescript", "tsx",
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
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
