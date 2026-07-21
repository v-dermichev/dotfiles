-- All vim options live here (loaded from init.lua right after lazy).
-- Theme/highlight setup stays in init.lua; leader keys in config/lazy.lua
-- (they must be set before lazy loads plugins).
local opt = vim.opt

-- ---------------------------------------------------------------------------
-- Clipboard / GUI
-- ---------------------------------------------------------------------------
opt.clipboard = { "unnamedplus" } -- Use system clipboard as the default register
vim.o.guifont = "JetBrainsMono Nerd Font:h8"

-- ---------------------------------------------------------------------------
-- Indentation and tabs
-- ---------------------------------------------------------------------------
opt.expandtab = true       -- Convert tabs to spaces
opt.tabstop = 4            -- Display width of a tab character
opt.shiftwidth = 4         -- Number of spaces to use for auto-indent
opt.smartindent = true     -- Smart auto-indenting for new lines

-- ---------------------------------------------------------------------------
-- UI / Display
-- ---------------------------------------------------------------------------
opt.number = true          -- Show absolute line number on current line
opt.relativenumber = true  -- Show relative line numbers for other lines
opt.cursorline = true      -- Highlight the line where the cursor is
opt.signcolumn = "yes"     -- Always show the sign column (for git/lsp)
opt.wrap = false           -- Don't wrap long lines

-- Default border for floating windows (LSP hover/K, signature help,
-- diagnostic floats). Matches blink.cmp's rounded documentation window.
opt.winborder = "rounded"

-- Gutter layout with breathing room: a leading pad so signs aren't jammed
-- against the window edge, the relative/absolute line number right-aligned,
-- and a trailing pad so the number isn't glued to the buffer text.
opt.statuscolumn =
  " %s%=%{% v:relnum == 0 ? '%#CursorLineNr#' . v:lnum : '%#LineNr#' . v:relnum %}  "

-- ---------------------------------------------------------------------------
-- Editing behavior
-- ---------------------------------------------------------------------------
opt.mouse = "a"            -- Enable mouse support
opt.ignorecase = true      -- Case-insensitive search by default
opt.smartcase = true       -- Case-sensitive if search contains uppercase
opt.incsearch = true       -- Show matches while typing search
opt.hlsearch = true        -- Highlight search matches
opt.backup = false         -- Don't use backup files
opt.writebackup = false    -- Don't keep backup before overwriting files
opt.swapfile = false       -- Disable swap files
opt.undofile = true        -- Persistent undo (saves undo history)
opt.scrolloff = 5          -- Keep 5 lines visible above/below cursor
opt.sidescrolloff = 8      -- Keep 8 columns visible when scrolling sideways
opt.updatetime = 250       -- Faster CursorHold: gitsigns blame, LSP highlights
-- NOTE: leave splitright/splitbelow at defaults — enabling them broke the
-- neo-tree sidebar width in the session-restore layout dance (2026-07-22).

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  severity_sort = true,
})
