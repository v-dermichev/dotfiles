-- Autosave + external-change refresh.
--
-- Autosave: modified plain-file buffers are written automatically — debounced
-- after normal-mode edits (TextChanged), and immediately on leaving insert
-- mode (Esc or <C-c>, via ModeChanged) or when the buffer / Neovim loses
-- focus (BufLeave / FocusLost) so external tools always operate on current
-- file content. dadbod-ui query buffers are excluded: with
-- db_ui_execute_on_save every :w RUNS the query, so autosave would fire SQL.
--
-- Refresh: autoread + :checktime on the events that follow an external change
-- (regaining focus, re-entering a buffer, leaving/closing the embedded
-- terminal where codegen and <leader>r commands run), so buffers pick up
-- on-disk edits without a manual :e. A modified buffer whose file also changed
-- on disk still gets Vim's W12 prompt — that conflict needs a human.

local M = {}

M.debounce_ms = 750

function M.eligible(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.bo[buf].modified
    and vim.bo[buf].buftype == ""
    and vim.bo[buf].modifiable
    and not vim.bo[buf].readonly
    and vim.api.nvim_buf_get_name(buf) ~= ""
    and vim.b[buf].dbui_db_key_name == nil -- dadbod query buffer: :w executes
end

function M.save(buf)
  if not M.eligible(buf) then return end
  vim.api.nvim_buf_call(buf, function()
    -- `update` (not `write`): no-op when nothing changed. silent! so a
    -- transient failure (permissions, deleted parent dir) never interrupts
    -- editing; lockmarks keeps '[ '] stable across the implicit write.
    vim.cmd("silent! lockmarks update")
  end)
end

function M.save_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    M.save(buf)
  end
end

-- Debounced save: (re)arms a single shared timer; quick successive edits
-- collapse into one write once typing pauses.
function M.schedule_save()
  M.timer:stop()
  M.timer:start(M.debounce_ms, 0, vim.schedule_wrap(function()
    -- Mid-insert fire (timer armed by TextChanged, then user entered insert):
    -- skip; the ModeChanged save covers the moment insert mode ends.
    if vim.fn.mode():match("^i") then return end
    M.save_all()
  end))
end

-- Files changed by an external agent since they were last viewed, keyed by
-- normalized path. Rendered as a badge by the neo-tree `agent_mark` component
-- (plugins/neotree.lua); opening the file clears its entry. Session-scoped.
M.marks = {}

function M.is_marked(path)
  return M.marks[vim.fs.normalize(path)] == true
end

-- Any marked file below this directory — keeps the dir badge in the tree
-- until every marked file underneath has been viewed.
function M.has_marked_below(dir)
  local prefix = vim.fs.normalize(dir) .. "/"
  for p in pairs(M.marks) do
    if vim.startswith(p, prefix) then return true end
  end
  return false
end

function M.clear_mark(path)
  local p = vim.fs.normalize(path)
  if not M.marks[p] then return end
  M.marks[p] = nil
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if ok then pcall(manager.refresh, "filesystem") end
end

-- RPC entry point for external tools (Claude Code PostToolUse hook): called
-- via `nvim --server <sock> --remote-expr` right after an agent modifies or
-- creates a file. Reloads the buffer holding that path (if any is loaded) and
-- refreshes the neo-tree filesystem view when the path lies inside the tree's
-- root — so created files appear even though no buffer holds them. Returns a
-- bitmask visible to the caller as expr output: +1 buffer checked, +2 tree
-- refreshed.
function M.external_change(path)
  local result = 0
  -- Literal name comparison: bufnr(string) does file-pattern matching, so
  -- wildcard chars in a path ([], *, ?, {}) would corrupt the lookup.
  local p = vim.fs.normalize(path)
  local buf
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b)
      and vim.fs.normalize(vim.api.nvim_buf_get_name(b)) == p then
      buf = b
      break
    end
  end
  if buf and vim.fn.getcmdwintype() == "" then
    vim.cmd("checktime " .. buf)
    result = result + 1
  end
  -- The tree's root can diverge from cwd (set_root remap), so gate on the
  -- filesystem state's own path. use_libuv_file_watcher only covers dirs
  -- neo-tree already watches; this refresh is deterministic.
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if ok then
    local state = manager.get_state("filesystem")
    local root = vim.fs.normalize(state and state.path or vim.fn.getcwd())
    local p = vim.fs.normalize(path)
    if p == root or vim.startswith(p, root .. "/") then
      -- Badge the file in the tree — unless it's on screen right now, where
      -- the reload itself is already visible.
      if not (buf and vim.fn.bufwinid(buf) ~= -1) then
        M.marks[p] = true
      end
      pcall(manager.refresh, "filesystem")
      result = result + 2
    end
  end
  return result
end

function M.checktime()
  -- :checktime is forbidden in the cmdline window; skip and let the next
  -- trigger event catch up.
  if vim.fn.getcmdwintype() ~= "" then return end
  vim.cmd("checktime")
end

function M.setup()
  M.timer = M.timer or vim.uv.new_timer()
  vim.o.autoread = true
  local group = vim.api.nvim_create_augroup("AutosaveRefresh", { clear = true })

  vim.api.nvim_create_autocmd("TextChanged", {
    group = group,
    callback = function() M.schedule_save() end,
  })
  -- Leaving insert saves immediately. ModeChanged (not InsertLeave): <C-c>
  -- exits insert mode without firing InsertLeave, but does change the mode.
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    pattern = "i*:*",
    callback = function(ev) M.save(ev.buf) end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
    group = group,
    callback = function(ev) M.save(ev.buf) end,
  })

  -- Opening an agent-marked file clears its tree badge.
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(ev)
      M.clear_mark(vim.api.nvim_buf_get_name(ev.buf))
    end,
  })

  -- External modifications (codegen, formatters, git) land while focus is
  -- elsewhere; these are the moments attention returns to the buffer.
  vim.api.nvim_create_autocmd(
    { "FocusGained", "BufEnter", "CursorHold", "TermLeave", "TermClose", "VimResume" },
    { group = group, callback = function() M.checktime() end }
  )
  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = group,
    callback = function(ev)
      vim.notify(
        "Reloaded (changed on disk): " .. vim.fn.fnamemodify(ev.file, ":~:."),
        vim.log.levels.INFO
      )
    end,
  })
end

return M
