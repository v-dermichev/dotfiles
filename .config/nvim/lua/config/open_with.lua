local M = {}

-- Where .desktop entries live, most-specific (user overrides) first.
local app_dirs = {
  vim.fn.expand("~/.local/share/applications"),
  "/usr/share/applications",
  "/usr/local/share/applications",
}

local function find_desktop(id)
  for _, dir in ipairs(app_dirs) do
    local p = dir .. "/" .. id
    if vim.fn.filereadable(p) == 1 then
      return p
    end
  end
end

-- Pull Name/Exec off the primary [Desktop Entry] group. First occurrence wins,
-- so trailing [Desktop Action ...] groups never shadow the main entry, and the
-- canonical `Name=` is preferred over any localized `Name[xx]=`.
local function parse_desktop(id)
  local p = find_desktop(id)
  if not p then
    return nil
  end
  local d = {}
  for _, line in ipairs(vim.fn.readfile(p)) do
    if not d.name then
      d.name = line:match("^Name=(.+)$")
    end
    if not d.exec then
      d.exec = line:match("^Exec=(.+)$")
    end
    -- Only Hidden=true means the entry is disabled/deleted. NoDisplay=true just
    -- keeps it out of app menus (imv, satty, ... set it) yet it is still a valid
    -- handler, so it belongs in an "open with" list.
    if line:match("^Hidden=true") then
      d.hidden = true
    end
  end
  return d
end

-- Turn a desktop Exec into a runnable command: field codes for the file/url
-- (%f %F %u %U) become the escaped path, every other %-code is dropped, and a
-- literal %% collapses to %.
local function exec_to_cmd(exec, path)
  local quoted = vim.fn.shellescape(path)
  exec = exec:gsub("%%%%", "\1")
  exec = exec:gsub("%%[fFuU]", quoted)
  exec = exec:gsub("%%%a", "")
  exec = exec:gsub("\1", "%%")
  return vim.trim(exec)
end

-- Neovim's current Hyprland workspace as an exec-rule selector, or nil off
-- Hyprland / on error. Special workspaces (our docked "IDE" scratchpad) carry a
-- negative id and are addressed by name (`special:IDE`); regular workspaces by
-- numeric id. Without this pin, a window launched from a special workspace maps
-- onto the regular workspace beneath the overlay instead of beside the editor.
local function current_workspace_selector()
  if not vim.env.HYPRLAND_INSTANCE_SIGNATURE then
    return nil
  end
  local ok, ws = pcall(vim.fn.json_decode, vim.fn.system({ "hyprctl", "activeworkspace", "-j" }))
  if not ok or type(ws) ~= "table" or ws.id == nil then
    return nil
  end
  if ws.id < 0 then
    return "special:" .. (tostring(ws.name):gsub("^special:", ""))
  end
  return tostring(ws.id)
end

-- Spawn detached. On Hyprland the launch is routed through `hyprctl dispatch
-- exec` with a per-launch inline rule set: the window is pinned to Neovim's
-- current workspace (`silent`, so focus/visibility are untouched -- it just
-- materializes on the workspace already in front of us) and, when `float` is
-- set, floated+centered. Building the rule per launch keeps it scoped to what
-- we open from here -- no global rule. Off Hyprland, spawn tiled as usual.
local function launch(cmd, float)
  if not vim.env.HYPRLAND_INSTANCE_SIGNATURE then
    vim.fn.jobstart({ "sh", "-c", cmd }, { detach = true })
    return
  end

  local rules = {}
  local ws = current_workspace_selector()
  if ws then
    rules[#rules + 1] = "workspace " .. ws .. " silent"
  end
  if float then
    rules[#rules + 1] = "float"
    rules[#rules + 1] = "center"
  end

  local prefix = #rules > 0 and ("[" .. table.concat(rules, "; ") .. "] ") or ""
  vim.fn.jobstart({ "hyprctl", "dispatch", "exec", prefix .. cmd }, { detach = true })
end

-- Desktop ids registered for a mime type, default first, deduped.
local function apps_for_mime(mime)
  local out = vim.fn.system({ "gio", "mime", mime })
  local default = out:match("Default application[^:]*:%s*([%w%-%+%._]+%.desktop)")
  local block = out:match("Recommended applications:(.*)")
    or out:match("Registered applications:(.*)")
    or ""

  local ids, seen = {}, {}
  local function add(id)
    if id and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  add(default)
  for id in block:gmatch("([%w%-%+%._]+%.desktop)") do
    add(id)
  end

  local entries = {}
  for _, id in ipairs(ids) do
    local d = parse_desktop(id)
    if d and not d.hidden and d.exec and d.exec ~= "" then
      entries[#entries + 1] = {
        name = d.name or id,
        exec = d.exec,
        is_default = id == default,
      }
    end
  end
  return entries
end

-- Shared front end: hovered file path, its mime type, and the registered apps.
-- Returns nil (after notifying) when there is nothing to open.
local function resolve(state)
  local node = state.tree:get_node()
  local path = node and node.path
  -- Directories are a first-class mime type (inode/directory), so folders get
  -- an "open with" menu too (file managers, neovide, ...), not just files.
  if not path or (node.type ~= "file" and node.type ~= "directory") then
    return nil
  end

  local mime = vim.trim(vim.fn.system({ "xdg-mime", "query", "filetype", path }))
  if mime == "" then
    vim.notify("Could not determine mime type for " .. path, vim.log.levels.WARN)
    return nil
  end

  local entries = apps_for_mime(mime)
  if #entries == 0 then
    vim.notify("No applications registered for " .. mime, vim.log.levels.WARN)
    return nil
  end
  return path, mime, entries
end

-- Lightweight in-process menu via nui.nvim (a neo-tree dependency). Avoids
-- routing through vim.ui.select -> fzf-lua, which spawns an external fzf
-- process in a terminal buffer and takes ~1-2s to appear (worse under Neovide)
-- for what is a small fixed action list.
local function popup_select(entries, prompt, on_choice)
  local Menu = require("nui.menu")
  local lines, width = {}, #prompt + 2
  for _, e in ipairs(entries) do
    local text = "  " .. e.name .. (e.is_default and "  (default)" or "")
    width = math.max(width, #text + 2)
    lines[#lines + 1] = Menu.item(text, { entry = e })
  end

  Menu({
    relative = "editor",
    position = "50%",
    size = { width = width, height = #lines },
    border = {
      style = "rounded",
      text = { top = " " .. prompt .. " ", top_align = "center" },
    },
    win_options = {
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual",
    },
  }, {
    lines = lines,
    keymap = {
      focus_next = { "j", "<Down>", "<Tab>" },
      focus_prev = { "k", "<Up>", "<S-Tab>" },
      close = { "<Esc>", "q", "<C-c>" },
      submit = { "<CR>", "l", "o" },
    },
    on_submit = function(item)
      on_choice(item.entry)
    end,
  }):mount()
end

-- neo-tree command: pick an xdg app for the hovered file's mime type and launch
-- it. `opts.float` (default true) floats the window (o) vs tiled (O).
function M.open_with(state, opts)
  local path, mime, entries = resolve(state)
  if not path then
    return
  end

  local float = not (opts and opts.float == false)
  local prompt = "Open "
    .. vim.fn.fnamemodify(path, ":t")
    .. " ("
    .. mime
    .. ")"
    .. (float and "" or " [tiled]")
  popup_select(entries, prompt, function(entry)
    launch(exec_to_cmd(entry.exec, path), float)
  end)
  return true
end

-- neo-tree command: skip the menu, launch the first-priority (default) handler.
-- `opts.float` decides floating (q) vs tiled (Q).
function M.quick(state, opts)
  local path, _, entries = resolve(state)
  if not path then
    return
  end
  launch(exec_to_cmd(entries[1].exec, path), opts and opts.float)
  return true
end

return M
