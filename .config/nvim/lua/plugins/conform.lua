-- Opt-in formatting (no format-on-save). Python goes through ruff (lint-fix +
-- format); other filetypes use their usual tool, then the LSP formatter.
return {
  "stevearc/conform.nvim",
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
      mode = { "n", "v" },
      desc = "Format buffer",
    },
    {
      "<C-A-l>", -- PyCharm "Reformat Code"
      function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
      mode = { "n", "i", "v" },
      desc = "Reformat code",
    },
  },
  opts = {
    formatters_by_ft = {
      python = { "ruff_fix", "ruff_format" },
      lua = { "stylua" },
      json = { "jq" },
      javascript = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", stop_after_first = true },
    },
    -- Used by manual format() calls: fall back to the LSP formatter when no
    -- conform formatter is configured for the filetype.
    default_format_opts = { lsp_format = "fallback" },
  },
}
