-- Canonical window layout, enforced from one place.
--
--   ┌─────────┬───────────────────┐
--   │ tree    │                   │
--   ├─────────┤      editors      │   left column: tree above drawer
--   │ drawer  │                   │   (either optional)
--   ├─────────┴───────────────────┤
--   │ slot (terminal/dbout/ext)   │   full width along the bottom
--   └─────────────────────────────┘
--
-- apply() is an idempotent normalizer: it classifies every window by role
-- and moves/resizes only what deviates. Callers run sync() in the same tick
-- as whatever changed the layout (no intermediate repaint) plus a scheduled
-- pass as safety net. Occupancy of the slot (WHICH single pane shows)
-- belongs to config.term_tabs; this module only enforces geometry.
--
-- Sizing philosophy: user resizes win. The tree's width is the reference
-- for the whole left column; the slot keeps whatever height it has unless
-- it was just docked or got crushed; in-column heights use natural splits.
local M = {}

M.dims = { sidebar_w = 32, slot_h = 12 }

local api = vim.api

local function role_of(win)
  if api.nvim_win_get_config(win).relative ~= "" then return nil end -- float
  local buf = api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  if ft == "neo-tree" then return "tree" end
  if ft == "dbui" then return "drawer" end
  if ft == "dbout" or vim.bo[buf].buftype == "terminal" then return "slot" end
  local ok, tt = pcall(require, "config.term_tabs")
  if ok then
    for _, e in ipairs(tt._ext or {}) do
      if e.buf == buf then return "slot" end
    end
  end
  if vim.bo[buf].buftype == "" then return "editor" end
  return nil
end

local function scan()
  local s = { slots = {}, editors = {} }
  for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
    local r = role_of(w)
    if r == "tree" then s.tree = w
    elseif r == "drawer" then s.drawer = w
    elseif r == "slot" then table.insert(s.slots, w)
    elseif r == "editor" then table.insert(s.editors, w)
    end
  end
  return s
end

local function col(win) return api.nvim_win_get_position(win)[2] end

function M.apply()
  pcall(function()
    local s = scan()

    -- 1) slot panes: full width along the bottom. Height is asserted only
    --    on a fresh dock or crush-rescue so user resizes survive.
    for _, w in ipairs(s.slots) do
      local docked_now = false
      if api.nvim_win_get_width(w) < vim.o.columns then
        api.nvim_win_call(w, function() vim.cmd("wincmd J") end)
        docked_now = true
      end
      if docked_now or api.nvim_win_get_height(w) < 3 then
        pcall(api.nvim_win_set_height, w, M.dims.slot_h)
      end
    end

    -- 2) left column: tree above drawer, drawer width follows the tree.
    if s.tree and s.drawer then
      if col(s.tree) ~= col(s.drawer) then
        pcall(vim.fn.win_splitmove, s.drawer, s.tree, { rightbelow = true })
      end
      pcall(api.nvim_win_set_width, s.drawer, api.nvim_win_get_width(s.tree))
    elseif s.drawer and not s.tree and #s.editors > 0 then
      -- drawer alone must not own a frame-level full-height column (that
      -- squeezes the slot's width): keep it inside the editor row, left.
      local editor = s.editors[1]
      if api.nvim_win_get_height(s.drawer) > api.nvim_win_get_height(editor) + 2 then
        pcall(vim.fn.win_splitmove, s.drawer, editor, { vertical = true })
        api.nvim_win_call(s.drawer, function() vim.cmd("wincmd H") end)
      end
      pcall(api.nvim_win_set_width, s.drawer, M.dims.sidebar_w)
    end

    -- 3) column moves can redistribute the slot; rescue a crushed one.
    for _, w in ipairs(s.slots) do
      if api.nvim_win_get_height(w) < 3 then
        pcall(api.nvim_win_set_height, w, M.dims.slot_h)
      end
    end
  end)
end

-- Same-tick + scheduled safety net (the standard no-jump pattern).
function M.sync()
  M.apply()
  vim.schedule(M.apply)
end

-- Auto-normalize when windows/buffers change: catches rogue splits made by
-- plugins that manage their own windows (e.g. dadbod's focus_window creating
-- a half-screen editor when none existed, or a sidebar left frame-height
-- after the last editor closed). Debounced to one apply per tick; the hot
-- paths still call sync() themselves for the same-tick no-jump guarantee.
local pending = false
function M.setup()
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinClosed", "TermOpen" }, {
    group = vim.api.nvim_create_augroup("LayoutAuto", { clear = true }),
    callback = function()
      if pending then return end
      pending = true
      vim.schedule(function()
        pending = false
        M.apply()
      end)
    end,
  })
end

return M
