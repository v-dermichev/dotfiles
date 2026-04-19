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

-- Toggle LSP inlay hints for current buffer
map.set("n", "<leader>ih", function()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
end, { desc = "Toggle inlay hints" })

-- Window (pane) navigation
map.set("n", "<C-h>", "<C-w>h", { desc = "Window: left" })
map.set("n", "<C-j>", "<C-w>j", { desc = "Window: down" })
map.set("n", "<C-k>", "<C-w>k", { desc = "Window: up" })
map.set("n", "<C-l>", "<C-w>l", { desc = "Window: right" })

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

local function escape(str)
  -- You need to escape these characters to work correctly
  local escape_chars = [[;,."|\]]
  return vim.fn.escape(str, escape_chars)
end

-- Recommended to use lua template string
local en = [[`qwertyuiop[]asdfghjkl;'zxcvbnm]]
local ru = [[ёйцукенгшщзхъфывапролджэячсмить]]
local en_shift = [[~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>]]
local ru_shift = [[ËЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ]]

vim.opt.langmap = vim.fn.join({
    -- | `to` should be first     | `from` should be second
    escape(ru_shift) .. ';' .. escape(en_shift),
    escape(ru) .. ';' .. escape(en),
}, ',')
