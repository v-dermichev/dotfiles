---@type LazySpec
return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = { "nvim-tree/nvim-web-devicons", "nvim-lua/plenary.nvim" },
  event = "VeryLazy",
  keys = {
    { "<S-h>",      "<cmd>BufferLineCyclePrev<cr>",   desc = "Buffer: prev" },
    { "<S-l>",      "<cmd>BufferLineCycleNext<cr>",   desc = "Buffer: next" },
    { "<leader>bp", "<cmd>BufferLineTogglePin<cr>",   desc = "Buffer: pin" },
    { "<leader>bc", "<cmd>bdelete<cr>",               desc = "Buffer: close" },
    { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Buffer: close others" },
  },
  opts = {
    options = {
      mode = "buffers",
      diagnostics = "nvim_lsp",
      always_show_bufferline = true,
      show_buffer_close_icons = true,
      show_close_icon = false,
      separator_style = "slant",
      -- Only show the file you're on (or one visible in a split) plus files
      -- pinned in the current project's Harpoon list. Keeps the bar to your
      -- ~6 registers instead of every buffer you've ever opened.
      custom_filter = function(buf, _)
        if buf == vim.api.nvim_get_current_buf() then
          return true
        end
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == buf then
            return true
          end
        end

        local ok, harpoon = pcall(require, "harpoon")
        if not ok then
          return true
        end

        local name = vim.api.nvim_buf_get_name(buf)
        if name == "" then
          return false
        end

        -- Harpoon stores each item's value relative to the cwd (its list key).
        local rel = require("plenary.path"):new(name):make_relative(vim.loop.cwd())
        for _, item in ipairs(harpoon:list().items) do
          if item and item.value == rel then
            return true
          end
        end
        return false
      end,
    },
  },
  init = function()
    vim.opt.showtabline = 2
  end,
  config = function(_, opts)
    require("bufferline").setup(opts)

    -- Refresh the bar the moment the Harpoon list changes so pin/unpin is
    -- reflected immediately instead of on the next redraw.
    local ok, ext = pcall(require, "harpoon.extensions")
    if ok then
      local refresh = function()
        pcall(function()
          require("bufferline.ui").refresh()
        end)
      end
      ext.extensions:add_listener({
        ADD = refresh,
        REMOVE = refresh,
        REORDER = refresh,
        LIST_CHANGE = refresh,
      })
    end
  end,
}
