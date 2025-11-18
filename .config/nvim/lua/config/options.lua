local opt = vim.opt;

opt.expandtab = true
opt.shiftwidth = 2

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  severity_sort = true,
})

