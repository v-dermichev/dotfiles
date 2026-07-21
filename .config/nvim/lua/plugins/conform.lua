-- Opt-in formatting (no format-on-save). Python goes through ruff (lint-fix +
-- format); other filetypes use their usual tool, then the LSP formatter.

-- Projects with a biome.json format + organize imports through Biome
-- (`biome check --write`); everything else keeps its usual formatter.
local function has_biome(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  return vim.fs.find({ "biome.json", "biome.jsonc" }, {
    upward = true,
    path = fname ~= "" and fname or vim.uv.cwd(),
  })[1] ~= nil
end

local function prefer_biome(fallback)
  return function(bufnr)
    if has_biome(bufnr) then return { "biome-check" } end
    return fallback
  end
end

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
      json = prefer_biome({ "jq" }),
      javascript = prefer_biome({ "prettierd", "prettier", stop_after_first = true }),
      typescript = prefer_biome({ "prettierd", "prettier", stop_after_first = true }),
      javascriptreact = prefer_biome({ "prettierd", "prettier", stop_after_first = true }),
      typescriptreact = prefer_biome({ "prettierd", "prettier", stop_after_first = true }),
    },
    -- Pin JS/JSON to 2-space indentation regardless of project config.
    formatters = {
      jq = { prepend_args = { "--indent", "2" } },
      prettier = { prepend_args = { "--tab-width", "2", "--use-tabs", "false" } },
      prettierd = { prepend_args = { "--tab-width", "2", "--use-tabs", "false" } },
    },
    -- Used by manual format() calls: fall back to the LSP formatter when no
    -- conform formatter is configured for the filetype.
    default_format_opts = { lsp_format = "fallback" },
  },
}
