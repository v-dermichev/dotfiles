-- Format-on-save. Python goes through ruff (lint-fix + format); other
-- filetypes fall back to their usual tools, then to the LSP formatter.
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format buffer",
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
    -- Any filetype not listed above is formatted by its LSP, if it supports it.
    default_format_opts = { lsp_format = "fallback" },
    format_on_save = { timeout_ms = 1500, lsp_format = "fallback" },
  },
}
