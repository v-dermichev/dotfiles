local options = { noremap = true, silent = true }
local map = vim.keymap

map.set('v', '<Tab>', '>', vim.tbl_extend("force", options, { desc = "Indent selection" }))
map.set('v', '<S-Tab>', '<', vim.tbl_extend("force", options, { desc = "Outdent selection" }))
-- map.set('n', '<Tab>', '>>', options)
-- map.set('n', '<S-Tab>', '<<', options)
-- map.set('n', '<C-a>', 'ggVG', options)

map.set("n", "<C-_>", "gccj_", { desc = "Toggle comment for current line", remap = true })
map.set('v', "<C-_>", "gc", { desc = "Toggle comment for current selection", remap = true })

if vim.g.neovide then
  map.set("n", "<C-/>", "gccj_", { desc = "Toggle comment for current line", remap = true })
  map.set('v', "<C-/>", "gc", { desc = "Toggle comment for current selection", remap = true })
end

-- Paste the system clipboard into a :terminal job (lazygit prompts, shells, …).
-- Needed under Neovide: it registers only the clipboard *provider*, not a paste
-- keybinding on Linux, so <C-S-v> otherwise does nothing in terminal mode and the
-- clipboard can't reach the running program. In kitty the emulator injects the
-- paste itself, so this is a harmless no-op key there. Sends '+' straight to the
-- terminal PTY via chansend; trailing newline is stripped so a copied URL doesn't
-- submit a lazygit prompt prematurely (lazygit doesn't enable bracketed paste).
map.set("t", "<C-S-v>", function()
  local chan = vim.b.terminal_job_id
  if chan then vim.fn.chansend(chan, (vim.fn.getreg("+"):gsub("\n$", ""))) end
end, { desc = "Terminal: paste system clipboard" })

-- Same Neovide gap for the cmdline and insert mode: unmapped <C-S-v> falls
-- through to C-v = literal-next (":" line shows ^ + the next key verbatim).
-- <C-r>+ inserts the clipboard register; the <C-o> variant in insert mode
-- pastes the text literally instead of re-running indent/abbreviations on it.
map.set("c", "<C-S-v>", "<C-r>+", { desc = "Cmdline: paste system clipboard" })
map.set("i", "<C-S-v>", "<C-r><C-o>+", { desc = "Insert: paste system clipboard" })

map.set("n", "<A-CR>", vim.lsp.buf.code_action, vim.tbl_extend("force", options, { desc = "Code action (intentions)" }))
map.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", options, { desc = "LSP hover" }))
map.set("n", "<leader>D", vim.diagnostic.open_float, vim.tbl_extend("force", options, { desc = "Diagnostic float" }))

-- Toggle the identifier of the declaration under the cursor in an
-- `export { ... }` block in the current file. Creates the block at
-- end-of-file if none exists; removes the name if already present.
map.set("n", "<leader><leader>e", function()
  -- name of the const/let/var/function/class/type/interface on this line
  local decl = vim.api.nvim_get_current_line():gsub("^%s*export%s+", "")
  local name = decl:match("^%s*[%a]+%s+([%a_$][%w_$]*)")
  if not name then
    vim.notify("No declaration found on this line", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- locate a local `export { ... }` block (skip re-exports: `... } from`)
  local si, ei
  for i, l in ipairs(lines) do
    if l:match("^%s*export%s*{") and not l:match("}%s*from") then
      si = i
      for j = i, #lines do
        if lines[j]:find("}") then ei = j break end
      end
      break
    end
  end

  if not si or not ei then
    -- no block yet: append one at EOF
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "", "export { " .. name .. " }" })
    return
  end

  -- collect existing names from between the braces
  local inner = table.concat(vim.list_slice(lines, si, ei), "\n"):match("{(.-)}") or ""
  local names, found = {}, nil
  for part in inner:gmatch("[^,]+") do
    local t = vim.trim(part)
    if t ~= "" then
      table.insert(names, t)
      if t:match("^([%w_$]+)") == name then found = #names end
    end
  end

  if found then table.remove(names, found) else table.insert(names, name) end

  local indent = lines[si]:match("^%s*")
  local out
  if #names == 0 then
    out = {} -- block becomes empty: drop it entirely
  elseif ei > si then
    out = { indent .. "export {" }
    for _, t in ipairs(names) do table.insert(out, indent .. "  " .. t .. ",") end
    table.insert(out, indent .. "}")
  else
    out = { indent .. "export { " .. table.concat(names, ", ") .. " }" }
  end
  vim.api.nvim_buf_set_lines(0, si - 1, ei, false, out)
end, vim.tbl_extend("force", options, { desc = "Toggle name in export block" }))

-- Interactive NuGet package management (fzf pickers with info/download preview)
map.set("n", "<leader>pa", function()
  require("config.nuget").pick()
end, vim.tbl_extend("force", options, { desc = "NuGet: add package (search)" }))
map.set("n", "<leader>pr", function()
  require("config.nuget").remove()
end, vim.tbl_extend("force", options, { desc = "NuGet: remove package" }))
map.set("n", "<leader>pu", function()
  require("config.nuget").update()
end, vim.tbl_extend("force", options, { desc = "NuGet: update package" }))

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

-- Hot-reload config: bust the require cache for the stateless config modules,
-- then re-source init.lua. Re-sourcing re-applies init.lua's own top-level
-- settings (options, highlights, colorscheme), re-requires the cleared modules
-- fresh, and re-runs the idempotent setup()s (venv / line_length use clear=true
-- augroups, so nothing duplicates). Stateful modules (config.term_tabs) are
-- intentionally NOT cleared, so open terminals survive the reload.
--
-- Not covered: plugin specs -> `:Lazy reload <name>`; edits to stateful modules
-- -> restart. Removed maps also linger until restart (reload only re-adds).
map.set("n", "<leader><leader>r", function()
  package.loaded["config.keymaps"] = nil
  package.loaded["config.options"] = nil
  vim.cmd("source " .. vim.fn.stdpath("config") .. "/init.lua")
  vim.notify("Config reloaded", vim.log.levels.INFO)
end, vim.tbl_extend("force", options, { desc = "Hot-reload config" }))


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

-- Yank the *rendered* selection: real buffer text with virtual text woven in
-- (inlay hints and inline dap-virtual-text at their columns, eol/diagnostic
-- virt_text appended at line end, virt_lines as their own lines). Virtual text
-- lives in extmarks and is normally invisible to a plain `y`; this composes what
-- you actually see on screen and puts it in the yank register.
local function chunks_to_str(chunks)
  local parts = {}
  for _, c in ipairs(chunks or {}) do parts[#parts + 1] = c[1] end
  return table.concat(parts)
end

local function yank_rendered()
  local buf = 0
  local vpos, cpos = vim.fn.getpos("v"), vim.fn.getpos(".")
  local mode = vim.fn.mode()
  local linewise = mode == "V"
  local blockwise = mode == "\22" -- <C-v>
  local rtype = linewise and "V" or (blockwise and "b" or "v")

  -- Normalised, 0-based selection bounds (end col inclusive).
  local sr, sc = vpos[2] - 1, vpos[3] - 1
  local er, ec = cpos[2] - 1, cpos[3] - 1
  if sr > er or (sr == er and sc > ec) then
    sr, sc, er, ec = er, ec, sr, sc
  end

  -- Real text, correct for charwise/linewise/blockwise and multibyte.
  local real = vim.fn.getregion(vpos, cpos, { type = rtype })

  -- Bucket the extmarks overlapping the row range by kind.
  local inline_by_row, eol_by_row, vlines_by_row = {}, {}, {}
  local marks = vim.api.nvim_buf_get_extmarks(buf, -1, { sr, 0 }, { er, -1 }, { details = true })
  for _, m in ipairs(marks) do
    local row, col, d = m[2], m[3], m[4]
    if d.virt_text and #d.virt_text > 0 then
      local pos = d.virt_text_pos
      if pos == "inline" or pos == "overlay" then
        inline_by_row[row] = inline_by_row[row] or {}
        table.insert(inline_by_row[row], { col = col, text = chunks_to_str(d.virt_text) })
      else -- eol / right_align (and the eol default)
        eol_by_row[row] = eol_by_row[row] or {}
        table.insert(eol_by_row[row], chunks_to_str(d.virt_text))
      end
    end
    if d.virt_lines and #d.virt_lines > 0 then
      vlines_by_row[row] = vlines_by_row[row] or {}
      table.insert(vlines_by_row[row], { above = d.virt_lines_above, lines = d.virt_lines })
    end
  end

  local out = {}
  for i, text in ipairs(real) do
    local row = sr + i - 1
    local full = vim.fn.getline(row + 1)
    local a, b -- selected byte window [a, b) of the full line
    if linewise then
      a, b = 0, #full
    elseif blockwise then
      a, b = sc, ec + 1
    else
      a = (row == sr) and sc or 0
      b = (row == er) and (ec + 1) or #full
    end

    -- virt_lines attached above this row.
    for _, vl in ipairs(vlines_by_row[row] or {}) do
      if vl.above then
        for _, ln in ipairs(vl.lines) do out[#out + 1] = chunks_to_str(ln) end
      end
    end

    -- Inline/overlay virt_text inside the selected window, spliced right-to-left
    -- so earlier insertions don't shift later byte offsets.
    local composed = text
    local ins = {}
    for _, vt in ipairs(inline_by_row[row] or {}) do
      if vt.col >= a and vt.col <= b then ins[#ins + 1] = vt end
    end
    table.sort(ins, function(x, y) return x.col > y.col end)
    for _, vt in ipairs(ins) do
      local at = math.max(0, math.min(vt.col - a, #composed))
      composed = composed:sub(1, at) .. vt.text .. composed:sub(at + 1)
    end

    -- eol virt_text only when the selection reaches the end of the real line.
    if b >= #full then
      for _, t in ipairs(eol_by_row[row] or {}) do composed = composed .. t end
    end
    out[#out + 1] = composed

    -- virt_lines attached below this row.
    for _, vl in ipairs(vlines_by_row[row] or {}) do
      if not vl.above then
        for _, ln in ipairs(vl.lines) do out[#out + 1] = chunks_to_str(ln) end
      end
    end
  end

  local reg = (vim.v.register ~= "" and vim.v.register) or '"'
  vim.fn.setreg(reg, out, linewise and "V" or "v")
  if vim.o.clipboard:find("unnamedplus") then vim.fn.setreg("+", out) end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  vim.notify(("Yanked %d line(s) with virtual text"):format(#out))
end

map.set("x", "<leader>yv", yank_rendered,
  vim.tbl_extend("force", options, { desc = "Yank selection incl. virtual text" }))

-- Russian-layout support. `langmap` is the universal layer: it translates typed
-- keys before mapping resolution, so it covers plugin `keys = {}` maps that
-- langmapper.nvim misses (langmapper's hack_keymap only wraps maps registered
-- after it loads, and lazy registers plugin keys through a cached keymap.set
-- before that). Keep both: langmapper adds which-key Russian display for the
-- config maps, langmap guarantees every mapping works regardless of layout.
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
