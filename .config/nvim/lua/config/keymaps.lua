local options = { noremap = true, silent = true }
local map = vim.keymap

map.set('v', '<Tab>', '>', vim.tbl_extend("force", options, { desc = "Indent selection" }))
map.set('v', '<S-Tab>', '<', vim.tbl_extend("force", options, { desc = "Outdent selection" }))
-- map.set('n', '<Tab>', '>>', options)
-- map.set('n', '<S-Tab>', '<<', options)
-- map.set('n', '<C-a>', 'ggVG', options)

map.set("n", "<C-_>", "gccj_", { desc = "Toggle comment for current line", remap = true })
map.set('v', "<C-_>", "gc", { desc = "Toggle comment for current selection", remap = true })

map.set("n", "<A-CR>", vim.lsp.buf.code_action, vim.tbl_extend("force", options, { desc = "Code action (intentions)" }))

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

map.set("n", "<Leader><Leader>f", vim.lsp.buf.format, vim.tbl_extend("force", options, { desc = "Format buffer (LSP)" }))


map.set('n', '<leader>r', function()
  local file = vim.fn.expand('%:p')
  vim.cmd('w') -- save current file

  -- Python: run in the bottom terminal slot (terminal 1) so output shows as a
  -- terminal tab with ANSI colours and gf links. The active venv's interpreter
  -- is already first on the terminal's $PATH (see config.venv), so `python`
  -- resolves to it.
  --
  -- Run as a module (`python -m pkg.mod`) with the project root on PYTHONPATH
  -- so intra-package imports (`from examples.x import Y`) resolve. A bare
  -- `python file.py` only puts the file's own directory on sys.path, never the
  -- project root, so package imports fail at runtime. Falls back to running the
  -- file by path when its location can't form a valid dotted module name.
  if vim.bo.filetype == 'python' then
    local marker = vim.fs.find(
      { 'pyproject.toml', 'setup.py', 'setup.cfg', '.git', '.venv' },
      { path = vim.fs.dirname(file), upward = true }
    )[1]
    local root = marker and vim.fs.dirname(marker) or vim.fs.dirname(file)
    local module = file:sub(#root + 2):gsub('%.py$', ''):gsub('[/\\]', '.')
    -- Every dotted segment must be a valid Python identifier to run via -m;
    -- otherwise fall back to running the file by path. (Lua patterns can't
    -- quantify a group, so validate segment by segment.)
    local runnable_module = #module > 0
    for seg in module:gmatch('[^.]+') do
      if not seg:match('^[%a_][%w_]*$') then runnable_module = false end
    end
    local pp = 'PYTHONPATH=' .. vim.fn.shellescape(root) .. ' '
    local cmd
    if runnable_module then
      cmd = pp .. 'python -m ' .. module
    else
      cmd = pp .. 'python ' .. vim.fn.shellescape(file)
    end
    require('config.term_tabs').run(cmd)
    return
  end

  -- Default: .NET (C#). Find the nearest ancestor holding a .csproj (built-in
  -- vim.fs.root — no dependency on the deprecated lspconfig framework).
  local root_dir = vim.fs.root(file, function(nm) return nm:match("%.csproj$") ~= nil end)
  if root_dir then
    -- run the project via dotnet
    local csproj = vim.fn.glob(root_dir .. '/*.csproj')
    vim.cmd('!' .. 'dotnet run --project ' .. csproj)
  else
    -- single file execution
    vim.cmd('!' .. 'dotnet run ' .. file)
  end
end, { noremap = true, silent = true, desc = "Run current file (python / dotnet)" })

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
