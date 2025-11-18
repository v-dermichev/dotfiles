local options = { noremap = true, silent = true }
local map = vim.keymap

map.set('v', '<Tab>', '>', options)
map.set('v', '<S-Tab>', '<', options)
-- map.set('n', '<Tab>', '>>', options)
-- map.set('n', '<S-Tab>', '<<', options)
-- map.set('n', '<C-a>', 'ggVG', options)

map.set("n", "<C-_>", "gccj_", { desc = "Toggle comment for current line", remap = true })
map.set('v', "<C-_>", "gc", { desc = "Toggle comment for current selection", remap = true })

map.set("n", "<A-CR>", vim.lsp.buf.code_action, options)

map.set("n", "<Leader><Leader>f", vim.lsp.buf.format, options)


map.set('n', '<leader>r', function()
  local file = vim.fn.expand('%:p')
  local util = require('lspconfig.util')
  local root_dir = util.root_pattern('*.csproj')(file)

  vim.cmd('w') -- save current file

  if root_dir then
    -- run the project via dotnet
    local csproj = vim.fn.glob(root_dir .. '/*.csproj')
    vim.cmd('!' .. 'dotnet run --project ' .. csproj)
  else
    -- single file execution
    vim.cmd('!' .. 'dotnet run ' .. file)
  end
end, { noremap = true, silent = true })
