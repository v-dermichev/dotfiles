return {
  "nvim-treesitter/nvim-treesitter",
  enabled = "true",
  build = ":TSUpdate",
  event = "BufReadPost",
  config = function()
    require("nvim-treesitter.configs").setup {
      ensure_installed = { "python", "c_sharp", "lua", "json", "yaml", "css", "html", "javascript", "typescript" },
      highlight = { enable = true },
      indent = { enable = true },
      incremental_selection = { enable = true },
      textobjects = { enable = true },
    }
  end,
}
