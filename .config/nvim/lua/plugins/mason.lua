return {
  {
    "mason-org/mason.nvim",
    lazy = true,
    config = function()
      require('mason').setup({
        registries = {
          'github:Crashdummyy/mason-registry',
          'github:mason-org/mason-registry',
        },
      })
    end
  },

  {
    "mason-org/mason-lspconfig.nvim",
    lazy = true,
    dependencies = {
      "mason-org/mason.nvim"
    },
    config = function()
      require('mason-lspconfig').setup({
        -- ty (type checking) + ruff (lint/format) own Python.
        -- taplo owns TOML (the schema associations in lsp.lua target it).
        ensure_installed = { "lua_ls", "rust_analyzer", "jsonls", "ty", "ruff", "bashls", "yamlls", "lemminx", "taplo" },
      })
    end
  },
}
