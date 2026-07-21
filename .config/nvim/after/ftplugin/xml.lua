-- XML-family buffers (plain xml + csproj/slnx/axaml via filetype.add) use the
-- conventional 2-space indent. With the global shiftwidth=4, treesitter's xml
-- indentexpr (depth × shiftwidth) over-indents — e.g. 8 spaces for a child of
-- <PropertyGroup> in a 2-space csproj.
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2
vim.bo.tabstop = 2
