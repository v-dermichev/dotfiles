#!/bin/bash
# Layout regression matrix for config/layout.lua and its callers.
# Each scenario runs a fresh headless nvim and asserts the canonical layout
# invariants (see lua/config/layout.lua). Run: ~/.config/nvim/tests/layout-test.sh
set -u
FAIL=0

run_case() {
  local name="$1" lua="$2"
  local out
  out=$(timeout 90 nvim --headless +"lua vim.o.lines = 50 vim.o.columns = 200 vim.defer_fn(function()
    local function win_info()
      local s = { }
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(w).relative == '' then
          local b = vim.api.nvim_win_get_buf(w)
          local ft = vim.bo[b].filetype
          local bt = vim.bo[b].buftype
          local p = vim.api.nvim_win_get_position(w)
          local e = { ft = ft, bt = bt, row = p[1], col = p[2],
                      w = vim.api.nvim_win_get_width(w), h = vim.api.nvim_win_get_height(w) }
          if ft == 'neo-tree' then s.tree = e
          elseif ft == 'dbui' then s.drawer = e
          elseif ft == 'dbout' then s.dbout = e
          elseif bt == 'terminal' then s.term = e
          elseif bt == '' then s.editor = s.editor or e end
        end
      end
      return s
    end
    local function fail(msg) print('ASSERT-FAIL: ' .. msg) end
    $lua
  end, 6000)" 2>&1)
  if echo "$out" | grep -aq "ASSERT-FAIL\|E5108\|Error"; then
    echo "FAIL: $name"
    echo "$out" | grep -aE "ASSERT-FAIL|E5108|Error" | head -3 | sed 's/^/    /'
    FAIL=1
  else
    echo "PASS: $name"
  fi
}

# ── 1. drawer toggle cycles with tree+terminal: dims stable, shared column ──
run_case "drawer-toggle-stability" '
  require("config.term_tabs").show(1)
  vim.defer_fn(function()
    vim.cmd("Lazy load vim-dadbod-ui")
    vim.defer_fn(function()
      local fn = vim.fn.maparg(" q", "n", false, true).callback
      local w0 = win_info()
      for i = 1, 3 do
        fn()
        local o = win_info()
        if not o.drawer then fail("cycle " .. i .. ": no drawer") break end
        if o.drawer.col ~= o.tree.col then fail("cycle " .. i .. ": drawer not in tree column") end
        if o.tree.w ~= w0.tree.w then fail("cycle " .. i .. ": tree width drifted " .. w0.tree.w .. "->" .. o.tree.w) end
        fn()
        local c = win_info()
        if c.drawer then fail("cycle " .. i .. ": drawer did not close") end
        if c.term.h ~= w0.term.h then fail("cycle " .. i .. ": term height drifted " .. w0.term.h .. "->" .. c.term.h) end
      end
      vim.cmd("qa!")
    end, 3000)
  end, 2500)
'

# ── 2. treeless drawer: editor-row placement, terminal keeps full width ──
run_case "treeless-drawer-placement" '
  require("config.term_tabs").show(1)
  vim.defer_fn(function()
    vim.cmd("Neotree close")
    vim.cmd("Lazy load vim-dadbod-ui")
    vim.defer_fn(function()
      vim.fn.maparg(" q", "n", false, true).callback()
      vim.schedule(function()
        local o = win_info()
        if not o.drawer then fail("no drawer") end
        if o.drawer and o.term and o.drawer.h >= o.term.h + o.drawer.h - 2 then fail("drawer spans full height") end
        if o.term and o.term.w < vim.o.columns then fail("terminal lost full width: " .. o.term.w) end
        if o.drawer and o.editor and o.drawer.col >= o.editor.col then fail("drawer not left of editor") end
        vim.cmd("qa!")
      end)
    end, 3000)
  end, 2500)
'

# ── 3. drawer first, then tree: shared column, editor not crushed ──
run_case "drawer-then-tree-adoption" '
  require("config.term_tabs").show(1)
  vim.defer_fn(function()
    vim.cmd("Neotree close")
    vim.cmd("Lazy load vim-dadbod-ui")
    vim.defer_fn(function()
      vim.fn.maparg(" q", "n", false, true).callback()
      vim.cmd("Neotree show left")
      vim.defer_fn(function()
        local o = win_info()
        if not (o.tree and o.drawer) then fail("missing tree or drawer") end
        if o.tree and o.drawer and o.tree.col ~= o.drawer.col then fail("two sidebars: tree col " .. o.tree.col .. " drawer col " .. o.drawer.col) end
        if o.editor and o.editor.w < 40 then fail("editor crushed to " .. o.editor.w) end
        vim.cmd("qa!")
      end, 2500)
    end, 3000)
  end, 2500)
'

# ── 4. query execution with terminal open: single slot occupant ──
run_case "query-slot-exclusivity" '
  require("config.term_tabs").show(1)
  vim.defer_fn(function()
    vim.cmd("DB sqlite:/tmp/layout-test.db select 1")
    vim.defer_fn(function()
      vim.cmd("DB sqlite:/tmp/layout-test.db select 2")
      vim.defer_fn(function()
        local o = win_info()
        local slots = 0
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local b = vim.api.nvim_win_get_buf(w)
          if vim.bo[b].buftype == "terminal" or vim.bo[b].filetype == "dbout" then slots = slots + 1 end
        end
        if slots ~= 1 then fail("slot occupants = " .. slots .. " (want 1)") end
        if o.dbout and o.dbout.w < vim.o.columns then fail("dbout not full width") end
        vim.cmd("qa!")
      end, 3500)
    end, 3000)
  end, 2500)
'

# ── 5. editor opened while sidebars owned the frame: no half-screen split ──
run_case "editor-after-sidebar-expansion" '
  require("config.term_tabs").show(1)
  vim.defer_fn(function()
    vim.cmd("Lazy load vim-dadbod-ui")
    vim.defer_fn(function()
      -- close every editor so the tree column absorbs the frame
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local b = vim.api.nvim_win_get_buf(w)
        if vim.bo[b].buftype == "" then
          pcall(vim.api.nvim_win_close, w, false)
        end
      end
      vim.fn.maparg(" q", "n", false, true).callback() -- drawer joins the tree column
      vim.defer_fn(function()
        -- what dadbod focus_window does when it finds no editor:
        vim.cmd("vertical botright new")
        vim.cmd("edit " .. vim.fn.tempname() .. ".txt")
        vim.defer_fn(function()  -- allow the debounced layout.apply to run
          local o = win_info()
          if o.tree and o.tree.w > math.floor(vim.o.columns / 3) then
            fail("tree still " .. o.tree.w .. " wide (half-screen damage kept)")
          end
          if o.editor and o.editor.w < vim.o.columns - 40 then
            fail("editor only " .. o.editor.w .. " wide")
          end
          vim.cmd("qa!")
        end, 1500)
      end, 2500)
    end, 2500)
  end, 2500)
'

exit $FAIL
