return {
  "lewis6991/satellite.nvim",
  event = "VeryLazy",
  opts = {
    current_only = false,
    winblend = 30, -- slight transparency so the thumb reads as a soft overlay
    zindex = 40,
    excluded_filetypes = {
      "neo-tree",
      "neo-tree-popup",
      "toggleterm",
      "TelescopePrompt",
      "aerial",
      "lazy",
      "help",
    },
    width = 2,
    handlers = {
      cursor = { enable = true },
      search = { enable = true },
      diagnostic = { enable = true },
      gitsigns = { enable = true },
      marks = { enable = true, show_builtins = false },
      quickfix = { enable = true },
    },
  },
}
