-- Diagnostics / symbols panel (the "Problems" tab).
return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {
    focus = true,
  },
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",              desc = "Diagnostics (Trouble)" },
    { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics (Trouble)" },
    { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>",      desc = "Symbols (Trouble)" },
    { "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP defs/refs (Trouble)" },
    { "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                  desc = "Location list (Trouble)" },
    { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>",                   desc = "Quickfix list (Trouble)" },
  },
}
