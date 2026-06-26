-- "Terminal tab" helper on top of toggleterm.
-- Swapping hides the current terminal (state preserved) and opens the target
-- in the same slot, so it behaves like IDE-style terminal tabs.
--
-- Besides the numbered toggleterm terminals, the single bottom slot is also
-- shared by "external" terminal-like buffers that other plugins own — the
-- nvim-dap debuggee terminal and the neotest output panel. Each is registered
-- as an entry in `M._ext` and shown as an extra winbar tab.

local M = {}

-- External slot tabs: ordered array of
--   { key, buf, win, glyph, label, on_close?, delete_on_close? }
-- `win` is nil while the tab is hidden; `buf` persists until its owner drops it.
M._ext = {}

-- Nerd Font glyphs (as raw UTF-8 byte escapes so they survive file-writes).
local GLYPH_TERM    = "\xef\x92\x89"  -- nf-oct-terminal  (U+F489)
local GLYPH_GIT     = "\xef\x87\x92"  -- nf-fa-code_fork  (U+F1D2)
local GLYPH_DEBUG   = "\xef\x86\x88"  -- nf-fa-bug        (U+F188)
local GLYPH_TEST    = "\xef\x83\x83"  -- nf-fa-flask      (U+F0C3)
local GLYPH_CLOSE   = "\xef\x80\x8d"  -- nf-fa-times      (U+F00D)
local SLANT_LEFT    = "\xee\x82\xb8"  -- pl-left_soft_divider  (U+E0B8)
local SLANT_RIGHT   = "\xee\x82\xba"  -- pl-right_soft_divider (U+E0BA)

local DAP_WINBAR = "%!v:lua.require('config.term_tabs').winbar()"

local function terms()
  return require("toggleterm.terminal")
end

local function ext_index(key)
  for i, e in ipairs(M._ext) do
    if e.key == key then return i end
  end
end

local function ext_alive(e)
  return e ~= nil and e.buf ~= nil and vim.api.nvim_buf_is_valid(e.buf)
end

local function prune_ext()
  for i = #M._ext, 1, -1 do
    if not ext_alive(M._ext[i]) then table.remove(M._ext, i) end
  end
end

-- Find a window currently showing a terminal buffer.
local function find_term_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
      return win
    end
  end
end

local function slot_height()
  local win = find_term_win()
  return win and vim.api.nvim_win_get_height(win) or 12
end

-- Park the cursor on the last line so output panes follow new output.
local function scroll_bottom(win)
  if win and vim.api.nvim_win_is_valid(win) then
    local buf = vim.api.nvim_win_get_buf(win)
    pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

local function set_term_winbar(win)
  vim.wo[win].winbar = DAP_WINBAR
end

local function apply_term_local_maps(buf)
  local o = { buffer = buf }
  vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], o)
  for _, lhs in ipairs({ "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
    vim.keymap.set("t", lhs, ("<Cmd>wincmd %s<CR>"):format(lhs:sub(4, 4)), o)
  end
  for _, mode in ipairs({ "n", "t" }) do
    vim.keymap.set(mode, "<S-h>", function() M.cycle(-1) end, { buffer = buf, desc = "Terminal: prev tab" })
    vim.keymap.set(mode, "<S-l>", function() M.cycle(1) end, { buffer = buf, desc = "Terminal: next tab" })
  end
  -- Clickable file:line:col links (pytest / grep style).
  vim.keymap.set("n", "gf", function() M.goto_file_cursor() end, { buffer = buf, desc = "Open file:line under cursor" })
  vim.keymap.set("n", "gF", function() M.goto_file_cursor() end, { buffer = buf, desc = "Open file:line under cursor" })
  vim.keymap.set({ "n", "t" }, "<C-LeftMouse>", function() M.goto_file_mouse() end, { buffer = buf, desc = "Open file:line under mouse" })
end

local function hide_all_open()
  for _, t in pairs(terms().get_all(true)) do
    if t:is_open() then t:close() end
  end
  -- External tabs share the slot, so hide their windows too (keep buffers).
  for _, e in ipairs(M._ext) do
    if e.win and vim.api.nvim_win_is_valid(e.win) then
      pcall(vim.api.nvim_win_close, e.win, false)
      e.win = nil
    end
  end
end

local function open(id)
  vim.cmd(tostring(id) .. "ToggleTerm direction=horizontal size=12")
end

function M.show(id)
  local target = terms().get(id, true)
  -- Already visible → do nothing (don't close/toggle off).
  if target and target:is_open() then return end

  -- Preserve the pane's current height across the swap so the user's resize sticks.
  local term_win = find_term_win()
  local saved_height = term_win and vim.api.nvim_win_get_height(term_win) or nil

  hide_all_open()
  open(id)

  if saved_height then
    vim.schedule(function()
      local new_win = find_term_win()
      if new_win then vim.api.nvim_win_set_height(new_win, saved_height) end
    end)
  end
end

-- Hide any visible terminal; if none visible, open terminal 1 (or the last one shown).
M._last_shown = 1
function M.toggle()
  -- First try toggleterm-tracked instances.
  for _, t in pairs(terms().get_all(true)) do
    if t:is_open() then
      M._last_shown = t.id
      t:close()
      return
    end
  end
  -- Any external slot tab visible → hide it.
  for _, e in ipairs(M._ext) do
    if e.win and vim.api.nvim_win_is_valid(e.win) then
      pcall(vim.api.nvim_win_close, e.win, false)
      e.win = nil
      return
    end
  end
  -- Fallback: if any window is showing a terminal buffer (e.g. lazygit instance
  -- whose is_open() desynced), close that window directly.
  local term_win = find_term_win()
  if term_win then
    vim.api.nvim_win_close(term_win, true)
    return
  end
  M.show(M._last_shown or 1)
end

function M.new()
  local all = terms().get_all(true)
  local next_id = #all + 1
  M.show(next_id)
end

-- ── External slot tabs (debug terminal, test output) ────────────────────
-- Bring an already-registered external buffer back into the bottom slot.
function M.show_ext(key)
  prune_ext()
  local i = ext_index(key)
  if not i then return end
  local e = M._ext[i]
  -- Already visible somewhere → just focus it.
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(w) == e.buf then
      e.win = w
      vim.api.nvim_set_current_win(w)
      if e.follow then scroll_bottom(w) end
      return
    end
  end
  local height = slot_height()
  hide_all_open()
  vim.cmd("belowright " .. height .. "split")
  vim.api.nvim_win_set_buf(0, e.buf)
  e.win = vim.api.nvim_get_current_win()
  set_term_winbar(e.win)
  if e.follow then scroll_bottom(e.win) end
end

-- Scroll a registered tab's window to its last line (e.g. after new output).
function M.scroll_ext_bottom(key)
  local i = ext_index(key)
  if not i then return end
  local e = M._ext[i]
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(w) == e.buf then scroll_bottom(w); return end
  end
end

-- Create a fresh slot window for an external tab and return (win, buf) so the
-- caller (e.g. nvim-dap) can run its process inside it.
function M.open_ext_win(spec)
  local height = slot_height()
  hide_all_open()
  vim.cmd("belowright " .. height .. "new")
  spec.win = vim.api.nvim_get_current_win()
  spec.buf = vim.api.nvim_get_current_buf()
  local i = ext_index(spec.key)
  if i then M._ext[i] = spec else table.insert(M._ext, spec) end
  set_term_winbar(spec.win)
  apply_term_local_maps(spec.buf)
  return spec.win, spec.buf
end

-- Register an external buffer that some plugin just opened in the current
-- window (e.g. neotest's output panel) as a slot tab, applying the winbar.
function M.register_ext(spec)
  prune_ext()
  if not (spec.buf and vim.api.nvim_buf_is_valid(spec.buf)) then return end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(w) == spec.buf then spec.win = w break end
  end
  local i = ext_index(spec.key)
  if i then M._ext[i] = spec else table.insert(M._ext, spec) end
  if spec.win then set_term_winbar(spec.win) end
  -- Same tab-cycling / nav keymaps as the numbered and debug terminals, so
  -- <S-h>/<S-l> work inside this pane too.
  apply_term_local_maps(spec.buf)
  if spec.follow and spec.win then scroll_bottom(spec.win) end
  vim.schedule(function() pcall(vim.cmd, "redrawstatus") end)
end

-- Drop an external slot tab (e.g. when a debug session ends). Hides its window
-- if shown; the buffer itself is left to its owner.
function M.remove_ext(key)
  local i = ext_index(key)
  if not i then return end
  local e = M._ext[i]
  if e.win and vim.api.nvim_win_is_valid(e.win) then
    pcall(vim.api.nvim_win_close, e.win, false)
  end
  table.remove(M._ext, i)
  vim.schedule(function() pcall(vim.cmd, "redrawstatus") end)
end

-- Prepare the single slot for a panel a plugin is about to open: hide whatever
-- occupies it and leave a fresh bottom split focused. Used as neotest's
-- `output_panel.open` command so its buffer lands in the slot.
function M.open_panel_slot()
  local height = slot_height()
  hide_all_open()
  vim.cmd("belowright " .. height .. "split")
end

-- nvim-dap's terminal_win_cmd entry point.
function M.open_dap_win()
  return M.open_ext_win({
    key = "dap",
    glyph = GLYPH_DEBUG,
    label = "debug",
    delete_on_close = true,
    on_close = function() pcall(function() require("dap").terminate() end) end,
  })
end

function M.cycle(step)
  prune_ext()
  local ids = {}
  for _, t in pairs(terms().get_all(true)) do table.insert(ids, t.id) end
  table.sort(ids)

  local handles = {}
  for _, id in ipairs(ids) do table.insert(handles, { kind = "term", id = id }) end
  for _, e in ipairs(M._ext) do table.insert(handles, { kind = "ext", key = e.key }) end
  if #handles == 0 then open(1); return end

  -- Locate the slot currently focused (or merely open) to step from.
  local cur_buf = vim.api.nvim_get_current_buf()
  local idx
  for i, h in ipairs(handles) do
    if h.kind == "ext" then
      local e = M._ext[ext_index(h.key)]
      if e and e.buf == cur_buf then idx = i; break end
    else
      local t = terms().get(h.id, true)
      if t and t.bufnr == cur_buf then idx = i; break end
    end
  end
  if not idx then
    for i, h in ipairs(handles) do
      if h.kind == "term" then
        local t = terms().get(h.id, true)
        if t and t:is_open() then idx = i; break end
      end
    end
  end
  idx = (((idx or 1) - 1 + step) % #handles) + 1

  local h = handles[idx]
  if h.kind == "ext" then M.show_ext(h.key) else M.show(h.id) end
end

-- Winbar that mirrors the bufferline "slant" style used by file tabs.
local function label_for(t, idx)
  local cmd = t.cmd or ""
  if type(cmd) == "table" then cmd = table.concat(cmd, " ") end
  if cmd:find("lazygit") then
    return GLYPH_GIT .. " lazygit"
  end
  return GLYPH_TERM .. " " .. idx
end

function M.winbar()
  prune_ext()
  local ids = {}
  for _, t in pairs(terms().get_all(true)) do table.insert(ids, t.id) end
  table.sort(ids)

  if #ids == 0 and #M._ext == 0 then return "" end

  local current_buf = vim.api.nvim_get_current_buf()
  local parts = {}

  -- Render one slant-styled tab: the body (left slant + label) fires `click`,
  -- the trailing close glyph fires `close`. Each is its own clickable region.
  local function push_tab(selected, label, click, close)
    local hl_tab = selected and "BufferLineBufferSelected" or "BufferLineBuffer"
    local hl_sep = selected and "BufferLineSeparatorSelected" or "BufferLineSeparator"
    local body  = ("%%#%s#%s%%#%s# %s "):format(hl_sep, SLANT_LEFT, hl_tab, label)
    local x     = ("%%#%s#%s "):format(hl_tab, GLYPH_CLOSE)
    local right = ("%%#%s#%s"):format(hl_sep, SLANT_RIGHT)
    table.insert(parts, click .. body .. "%X" .. close .. x .. "%X" .. right)
    table.insert(parts, "%#BufferLineFill# ")
  end

  for i, id in ipairs(ids) do
    local t = terms().get(id, true)
    if t then
      push_tab(t.bufnr == current_buf, label_for(t, i),
        ("%%%d@v:lua.TermTabClick@"):format(id),
        ("%%%d@v:lua.TermTabClose@"):format(id))
    end
  end

  for i, e in ipairs(M._ext) do
    push_tab(e.buf == current_buf, e.glyph .. " " .. e.label,
      ("%%%d@v:lua.TermExtClick@"):format(i),
      ("%%%d@v:lua.TermExtClose@"):format(i))
  end

  table.insert(parts, "%#BufferLineFill#")
  return table.concat(parts, "")
end

-- Clickable winbar handler — exposed as a global so statusline %@…@ can resolve it.
-- minwid = terminal id; button: "l" left, "r" right, "m" middle.
_G.TermTabClick = function(minwid, _clicks, button, _mods)
  if button == "m" then
    local t = terms().get(minwid, true)
    if t then t:shutdown() end
    return
  end
  M.show(minwid)
end

-- Close glyph handler — shuts down the terminal whose id is `minwid`.
_G.TermTabClose = function(minwid, _clicks, _button, _mods)
  local t = terms().get(minwid, true)
  if t then t:shutdown() end
end

-- External tab handlers — `minwid` is the index into M._ext at render time.
_G.TermExtClick = function(minwid, _clicks, _button, _mods)
  local e = M._ext[minwid]
  if e then M.show_ext(e.key) end
end

_G.TermExtClose = function(minwid, _clicks, _button, _mods)
  local e = M._ext[minwid]
  if not e then return end
  if e.on_close then pcall(e.on_close) end
  if e.win and vim.api.nvim_win_is_valid(e.win) then
    pcall(vim.api.nvim_win_close, e.win, false)
  end
  if e.delete_on_close and e.buf and vim.api.nvim_buf_is_valid(e.buf) then
    pcall(vim.api.nvim_buf_delete, e.buf, { force = true })
  end
  table.remove(M._ext, minwid)
  vim.cmd("redrawstatus")
end

function M.lazygit()
  -- Lazygit uses a dedicated persistent Terminal instance (separate from the numbered ones).
  if not M._lazygit then
    M._lazygit = terms().Terminal:new({
      cmd = "lazygit",
      dir = "git_dir",
      direction = "horizontal",
      size = 15,
      hidden = true,
      close_on_exit = true,
      start_in_insert = true,
    })
  end
  if M._lazygit:is_open() then
    M._lazygit:close()
  else
    hide_all_open()
    M._lazygit:open()
  end
end

-- ── Clickable file:line:col links in terminal / output panes ─────────────
-- Parse a `path:line[:col]` token (pytest/grep/traceback style) and open it in
-- the main code window. `gf`/`gF` use the token under the cursor; Ctrl-click
-- uses the token under the mouse. When several tokens share a line, the one
-- spanning `col` wins, otherwise the first.
local function parse_path_token(text, col)
  local best, init = nil, 1
  while true do
    local s, e, file, lnum, cnum = text:find("([%w%._%+%-/]+):(%d+):?(%d*)", init)
    if not s then break end
    local cand = { file = file, lnum = tonumber(lnum), col = tonumber(cnum), s = s - 1, e = e - 1 }
    best = best or cand
    if col and col >= cand.s and col <= cand.e then return cand end
    init = e + 1
  end
  return best
end

-- A real, named file window to drop the opened file into (not a terminal,
-- aerial, trouble, etc.).
local function main_code_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= "" then return w end
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "" then return w end
  end
end

local function open_token(text, col)
  local tok = parse_path_token(text, col)
  if not tok then return end
  local path = tok.file
  if vim.fn.filereadable(path) == 0 then
    local abs = vim.fn.fnamemodify(path, ":p")
    if vim.fn.filereadable(abs) == 1 then path = abs end
  end
  if vim.fn.filereadable(path) == 0 then
    vim.notify("term: file not found: " .. tok.file, vim.log.levels.WARN)
    return
  end
  local win = main_code_win()
  if win then
    vim.api.nvim_set_current_win(win)
  else
    vim.cmd("aboveleft vsplit")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  pcall(vim.api.nvim_win_set_cursor, 0, { tok.lnum or 1, math.max((tok.col or 1) - 1, 0) })
  vim.cmd("normal! zz")
end

function M.goto_file_cursor()
  open_token(vim.api.nvim_get_current_line(), vim.api.nvim_win_get_cursor(0)[2])
end

function M.goto_file_mouse()
  local mp = vim.fn.getmousepos()
  if mp.winid == 0 or mp.line == 0 then return end
  local buf = vim.api.nvim_win_get_buf(mp.winid)
  local line = (vim.api.nvim_buf_get_lines(buf, mp.line - 1, mp.line, false) or {})[1]
  if not line then return end
  pcall(vim.api.nvim_set_current_win, mp.winid)
  open_token(line, mp.column - 1)
end

return M
