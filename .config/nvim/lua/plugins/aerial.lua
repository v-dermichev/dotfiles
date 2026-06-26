-- Code outline / structure panel (functions, classes, methods).
return {
  "stevearc/aerial.nvim",
  cmd = { "AerialToggle", "AerialOpen", "AerialNavToggle" },
  keys = {
    { "<leader>o", "<cmd>AerialToggle!<cr>", desc = "Outline (Aerial)" },
  },
  opts = {
    layout = { default_direction = "prefer_right" },
    attach_mode = "global",
    on_attach = function(bufnr)
      vim.keymap.set("n", "{", "<cmd>AerialPrev<cr>", { buffer = bufnr, desc = "Aerial: prev symbol" })
      vim.keymap.set("n", "}", "<cmd>AerialNext<cr>", { buffer = bufnr, desc = "Aerial: next symbol" })
    end,
  },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
}
