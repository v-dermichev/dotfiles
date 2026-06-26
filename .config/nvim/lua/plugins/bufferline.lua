---@type LazySpec
return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  keys = {
    { "<S-h>",       "<cmd>BufferLineCyclePrev<cr>",    desc = "Buffer: prev" },
    { "<S-l>",       "<cmd>BufferLineCycleNext<cr>",    desc = "Buffer: next" },
    { "<leader>bp",  "<cmd>BufferLineTogglePin<cr>",    desc = "Buffer: pin" },
    { "<leader>bc",  "<cmd>bdelete<cr>",                desc = "Buffer: close" },
    { "<leader>bo",  "<cmd>BufferLineCloseOthers<cr>",  desc = "Buffer: close others" },
  },
  opts = {
    options = {
      mode = "buffers",
      diagnostics = "nvim_lsp",
      always_show_bufferline = true,
      show_buffer_close_icons = true,
      show_close_icon = false,
      separator_style = "slant",
    },
  },
  init = function()
    vim.opt.showtabline = 2
  end,
}
