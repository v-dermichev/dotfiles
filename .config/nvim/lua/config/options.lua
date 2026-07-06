local opt = vim.opt;

opt.expandtab = true
opt.shiftwidth = 2

-- Default border for floating windows (LSP hover/K, signature help,
-- diagnostic floats). Matches blink.cmp's rounded documentation window.
opt.winborder = "rounded"

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  severity_sort = true,
})

