-- Floating DAP control widget: a tiny always-on-top bar at the top-right with
-- clickable, colour-coded continue / pause / step / terminate buttons. Hovering
-- a button pops a hint float showing its keyboard shortcuts. Shown while a debug
-- session is live (wired from lua/plugins/dap.lua) and hidden when it ends. It's
-- a plain floating window, so it never blocks editing or stepping.

local M = {}

local nr2char = vim.fn.nr2char

-- action = the require("dap") function to call; hl = per-button colour;
-- keys = shortcuts shown on hover.
local BUTTONS = {
  { name = "Continue",  glyph = nr2char(0xf04b), action = "continue",  hl = "DapCtrlContinue",  keys = "<F5>  ·  <leader>dc" },
  { name = "Pause",     glyph = nr2char(0xf04c), action = "pause",     hl = "DapCtrlPause",     keys = "<leader>dP" },
  { name = "Step Over", glyph = nr2char(0xf051), action = "step_over", hl = "DapCtrlStepOver",  keys = "<F10>  ·  <leader>do" },
  { name = "Step Into", glyph = nr2char(0xf063), action = "step_into", hl = "DapCtrlStepInto",  keys = "<F11>  ·  <leader>di" },
  { name = "Step Out",  glyph = nr2char(0xf062), action = "step_out",  hl = "DapCtrlStepOut",   keys = "<leader>dO" },
  { name = "Terminate", glyph = nr2char(0xf04d), action = "terminate", hl = "DapCtrlTerminate", keys = "<leader>dt" },
}

local COLORS = {
  DapCtrlContinue  = "#a6e3a1", -- green
  DapCtrlPause     = "#f9e2af", -- yellow
  DapCtrlStepOver  = "#89b4fa", -- blue
  DapCtrlStepInto  = "#94e2d5", -- teal
  DapCtrlStepOut   = "#cba6f7", -- mauve
  DapCtrlTerminate = "#f38ba8", -- red
}

local state = {
  buf = nil, win = nil, -- the control bar
  tip_buf = nil, tip_win = nil, -- the hover hint
  ranges = nil, -- per-button display-column ranges (1-based)
  saved_mousemove = nil, -- previous &mousemoveevent, restored on close
}

local function ensure_hl()
  for group, fg in pairs(COLORS) do
    vim.api.nvim_set_hl(0, group, { fg = fg, bold = true, default = true })
  end
end

-- Build the bar text, each button's display-column range (for hit-testing), the
-- overall width, and the per-glyph highlight byte-ranges (for colouring).
local function build()
  local parts, ranges, hls, dcol, byte = {}, {}, {}, 1, 0
  for i, b in ipairs(BUTTONS) do
    local cell = " " .. b.glyph .. " "
    local w = vim.fn.strdisplaywidth(cell)
    ranges[i] = { lo = dcol, hi = dcol + w - 1 }
    hls[i] = { group = b.hl, s = byte + 1, e = byte + 1 + #b.glyph } -- glyph bytes only
    parts[i] = cell
    dcol = dcol + w
    byte = byte + #cell
  end
  return table.concat(parts), ranges, dcol - 1, hls
end

local function button_at(wincol)
  if not state.ranges then return nil end
  for i, r in ipairs(state.ranges) do
    if wincol >= r.lo and wincol <= r.hi then return i end
  end
end

local function hide_tip()
  if state.tip_win and vim.api.nvim_win_is_valid(state.tip_win) then
    pcall(vim.api.nvim_win_close, state.tip_win, true)
  end
  state.tip_win = nil
end

local function show_tip(idx)
  local b = BUTTONS[idx]
  local text = " " .. b.name .. "   " .. b.keys .. " "
  if not (state.tip_buf and vim.api.nvim_buf_is_valid(state.tip_buf)) then
    state.tip_buf = vim.api.nvim_create_buf(false, true)
  end
  vim.bo[state.tip_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.tip_buf, 0, -1, false, { text })
  vim.bo[state.tip_buf].modifiable = false
  local cfg = {
    relative = "editor", anchor = "NE", row = 4, col = vim.o.columns,
    width = vim.fn.strdisplaywidth(text), height = 1, focusable = false,
    style = "minimal", border = "rounded", zindex = 251, noautocmd = true,
  }
  if state.tip_win and vim.api.nvim_win_is_valid(state.tip_win) then
    vim.api.nvim_win_set_config(state.tip_win, cfg)
  else
    state.tip_win = vim.api.nvim_open_win(state.tip_buf, false, cfg)
    vim.wo[state.tip_win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
  end
end

local function dispatch(action)
  local fn = require("dap")[action]
  if fn then pcall(fn) end
end

-- A real code window (normal, named file buffer) — never a terminal/tree/float
-- or the debug-output slot. dap jumps the stopped frame's source into the
-- current window, so continue/step must leave focus here, not in the slot.
local function code_win()
  local function is_code(w)
    if not vim.api.nvim_win_is_valid(w) or vim.api.nvim_win_get_config(w).relative ~= "" then
      return false
    end
    local b = vim.api.nvim_win_get_buf(w)
    return vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= ""
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_code(w) then return w end
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative == ""
      and vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "" then
      return w
    end
  end
end

-- <LeftMouse> focuses the float first, so this <LeftRelease> handler runs with
-- the bar as the current buffer: dispatch the clicked button, then park focus
-- in the code window so the resulting frame-jump lands there, not in the slot.
local function on_click()
  local mp = vim.fn.getmousepos()
  local idx = mp.winid == state.win and button_at(mp.wincol) or nil
  local dest = code_win()
  if idx then dispatch(BUTTONS[idx].action) end
  if dest and vim.api.nvim_win_is_valid(dest) then
    pcall(vim.api.nvim_set_current_win, dest)
  end
end

-- MouseMove fires regardless of focus (needs &mousemoveevent), so this is a
-- global handler active only for the widget's lifetime.
local function on_mousemove()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then return end
  local mp = vim.fn.getmousepos()
  local idx = mp.winid == state.win and button_at(mp.wincol) or nil
  if idx then show_tip(idx) else hide_tip() end
end

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then return end
  ensure_hl()
  local line, ranges, width, hls = build()
  state.ranges = ranges
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { line })
  local ns = vim.api.nvim_create_namespace("dap_controls")
  for _, h in ipairs(hls) do
    vim.api.nvim_buf_add_highlight(state.buf, ns, h.group, 0, h.s, h.e)
  end
  vim.bo[state.buf].modifiable = false
  vim.bo[state.buf].bufhidden = "wipe"
  state.win = vim.api.nvim_open_win(state.buf, false, {
    relative = "editor", anchor = "NE", row = 1, col = vim.o.columns,
    width = width, height = 1, focusable = true, style = "minimal",
    border = "rounded", zindex = 250, noautocmd = true,
  })
  vim.wo[state.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"

  vim.keymap.set("n", "<LeftRelease>", on_click, { buffer = state.buf, nowait = true, desc = "dap-controls: click button" })

  state.saved_mousemove = vim.o.mousemoveevent
  vim.o.mousemoveevent = true
  vim.keymap.set({ "n", "i" }, "<MouseMove>", on_mousemove, { desc = "dap-controls hover" })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("DapControlsLayout", { clear = true }),
    callback = function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        pcall(vim.api.nvim_win_set_config, state.win,
          { relative = "editor", anchor = "NE", row = 1, col = vim.o.columns })
      end
    end,
  })
end

function M.close()
  hide_tip()
  pcall(vim.keymap.del, { "n", "i" }, "<MouseMove>")
  if state.saved_mousemove ~= nil then
    vim.o.mousemoveevent = state.saved_mousemove
    state.saved_mousemove = nil
  end
  pcall(vim.api.nvim_del_augroup_by_name, "DapControlsLayout")
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win, state.buf, state.ranges = nil, nil, nil
end

return M
