-- Local plugin: gamifies Vim motions (see ~/repos/vim-gamify). Smelly moves
-- (hjkl/arrow/x spam) cost XP with a how-to-avoid tip; smart moves earn it.
return {
  dir = vim.fn.expand("~/repos/vim-gamify"),
  name = "vim-gamify",
  enabled = false, -- temporarily disabled
  lazy = false,
  config = function()
    require("gamify").setup({})
  end,
}
