require("config.lazy")
require("config.keymaps")
require("config.options")

-- vim.opt.clipboard = { "unnamed", "unnamedplus" } -- Use system clipboard as the default registers
vim.opt.clipboard = { "unnamedplus" } -- Use system clipboard as the default registers


vim.o.guifont = "JetBrainsMono Nerd Font:h10"

if vim.g.neovide then
    vim.g.neovide_window_width = 1200
    vim.g.neovide_window_height = 800
    vim.g.neovide_opacity = 0.95
    vim.g.neovide_cursor_animation_length = 0.05
    vim.g.neovide_scroll_animation_length = 0.1
    vim.g.neovide_remember_window_size = true
end

-- ---------------------------------------------------------------------------
-- Clipboard
-- ---------------------------------------------------------------------------
-- Use system clipboard as default register (syncs with Ctrl+C / Ctrl+V)
-- vim.opt.clipboard = "unnamedplus"

-- ---------------------------------------------------------------------------
-- Indentation and tabs
-- ---------------------------------------------------------------------------
vim.opt.expandtab = true       -- Convert tabs to spaces
vim.opt.tabstop = 4            -- Display width of a tab character
vim.opt.shiftwidth = 4         -- Number of spaces to use for auto-indent
vim.opt.smartindent = true     -- Smart auto-indenting for new lines

-- ---------------------------------------------------------------------------
-- UI / Display
-- ---------------------------------------------------------------------------
vim.opt.number = true          -- Show absolute line number on current line
vim.opt.relativenumber = true  -- Show relative line numbers for other lines
vim.opt.cursorline = true      -- Highlight the line where the cursor is
-- vim.opt.termguicolors = true   -- Enable 24-bit colors
vim.opt.signcolumn = "yes"     -- Always show the sign column (for git/lsp)
vim.opt.wrap = false           -- Don't wrap long lines

-- ---------------------------------------------------------------------------
-- Editing behavior
-- ---------------------------------------------------------------------------
vim.opt.mouse = "a"            -- Enable mouse support
vim.opt.ignorecase = true      -- Case-insensitive search by default
vim.opt.smartcase = true       -- Case-sensitive if search contains uppercase
vim.opt.incsearch = true       -- Show matches while typing search
vim.opt.hlsearch = true        -- Highlight search matches
vim.opt.backup = false         -- Don't use backup files
vim.opt.writebackup = false    -- Don't keep backup before overwriting files
vim.opt.swapfile = false       -- Disable swap files
vim.opt.undofile = true        -- Persistent undo (saves undo history)
vim.opt.scrolloff = 5          -- Keep 5 lines visible above/below cursor
vim.opt.sidescrolloff = 8      -- Keep 8 columns visible when scrolling sideways


-- ---------------------------------------------------------------------------
-- Optional settings (commented out for minimalism)
-- ---------------------------------------------------------------------------

-- vim.opt.colorcolumn = "80"       -- Show a ruler at column 80
-- vim.opt.list = true              -- Show invisible characters (tabs, spaces, etc.)
-- vim.opt.listchars = { tab = "▸ ", trail = "·", extends = "›", precedes = "‹" }
-- vim.opt.splitright = true        -- Vertical splits open to the right
-- vim.opt.splitbelow = true        -- Horizontal splits open below
-- vim.opt.showmode = false         -- Don’t show mode (since statusline can handle it)
-- vim.opt.laststatus = 3           -- Global statusline (Neovim 0.7+)
-- vim.opt.timeoutlen = 400         -- Faster key sequence timeout
-- vim.opt.updatetime = 250         -- Faster updates for diagnostics/autocmds
-- vim.opt.confirm = true           -- Ask before closing unsaved buffers
-- vim.opt.completeopt = { "menuone", "noselect" }  -- Better completion defaults

-- ---------------------------------------------------------------------------
-- End of config
-- ---------------------------------------------------------------------------


-- vim.cmd("colorscheme gruvbox-material")
-- vim.cmd("colorscheme kanagawa")
-- vim.cmd("colorscheme one_monokai")
-- vim.cmd("colorscheme onedark")
-- vim.cmd("colorscheme catppuccin-macchiato")
-- vim.cmd("colorscheme duskfox")
-- vim.cmd("colorscheme carbonfox")
-- vim.cmd("colorscheme NeoSolarized")
-- vim.cmd("colorscheme rose-pine")
vim.cmd.colorscheme("tokyonight-storm")
-- vim.cmd.colorscheme("tokyonight-night")
-- vim.cmd.colorscheme("tokyonight-moon")
-- vim.cmd.colorscheme("tokyonight")
-- vim.cmd.colorscheme("leaf")
-- vim.cmd("colorscheme cattpuccin")
-- vim.cmd("colorscheme cyberdream")
-- vim.cmd("colorscheme moonfly")
-- vim.cmd('colorscheme github_dark_colorblind')
-- vim.cmd('colorscheme material')
-- vim.cmd('colorscheme oldworld')
-- vim.cmd('colorscheme vague')
-- vim.cmd('colorscheme vscode')
-- vim.cmd('colorscheme fluoromachine')
-- vim.cmd('colorscheme eldritch')

vim.lsp.enable("lua_ls")
vim.lsp.enable("astro")
vim.lsp.enable("tsserver")
vim.lsp.enable("rust_analyzer")
vim.lsp.enable('jdtls')

