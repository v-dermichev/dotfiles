require("config.lazy")
require("config.keymaps")
require("config.options")
require("config.venv").setup()
require("config.line_length").setup()

vim.filetype.add({
  extension = {
    axaml = "xml",
    csproj = "xml",
    slnx = "xml",
  },
})

-- vim.opt.clipboard = { "unnamed", "unnamedplus" } -- Use system clipboard as the default registers
vim.opt.clipboard = { "unnamedplus" } -- Use system clipboard as the default registers


vim.o.guifont = "JetBrainsMono Nerd Font:h8"

if vim.g.neovide then
    vim.g.neovide_window_width = 1200
    vim.g.neovide_window_height = 800
    vim.g.neovide_opacity = 0.95
    vim.g.neovide_cursor_animation_length = 0.05
    vim.g.neovide_scroll_animation_length = 0.1
    vim.g.neovide_remember_window_size = true

    -- Ctrl+scroll to zoom the font, like a terminal/browser.
    vim.g.neovide_scale_factor = 1.0
    local function change_scale(delta)
        local new = vim.g.neovide_scale_factor + delta
        vim.g.neovide_scale_factor = math.max(0.5, math.min(new, 3.0))
    end
    vim.keymap.set({ "n", "i", "v", "t" }, "<C-ScrollWheelUp>", function() change_scale(0.1) end, { desc = "Neovide: zoom in" })
    vim.keymap.set({ "n", "i", "v", "t" }, "<C-ScrollWheelDown>", function() change_scale(-0.1) end, { desc = "Neovide: zoom out" })
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

-- Gutter layout with breathing room: a leading pad so signs aren't jammed
-- against the window edge, the relative/absolute line number right-aligned,
-- and a trailing pad so the number isn't glued to the buffer text.
vim.opt.statuscolumn =
  " %s%=%{% v:relnum == 0 ? '%#CursorLineNr#' . v:lnum : '%#LineNr#' . v:relnum %}  "

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
vim.cmd.colorscheme("pycharm-dark")
-- vim.cmd.colorscheme("tokyonight-storm")
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

-- More distinct pane separators while staying in the tokyonight palette.
vim.opt.fillchars:append({ vert = "┃", vertleft = "┫", vertright = "┣", horiz = "━", horizup = "┻", horizdown = "┳", verthoriz = "╋" })
-- One clear=true augroup for the highlight autocmds (here and apply_pycharm
-- below), so re-sourcing init.lua for hot-reload replaces them instead of
-- stacking a fresh anonymous handler on every reload.
local user_hl_group = vim.api.nvim_create_augroup("UserHighlights", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = user_hl_group,
  callback = function()
    vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#7aa2f7", bg = "NONE", bold = true })
  end,
})
vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#7aa2f7", bg = "NONE", bold = true })

-- ---------------------------------------------------------------------------
-- Semantic highlights (PyCharm / Darcula palette for LSP tokens)
-- ---------------------------------------------------------------------------
-- To revert to the tokyonight defaults, comment out the `apply_pycharm` call
-- at the end of this block; the colorscheme will supply its own values again.
local function apply_pycharm()
  -- --- JetBrains "Islands Dark" palette -----------------------------------
  local FG              = "#bcbec4" -- default text / local vars / parameters
  local VAR             = "#bcbec4" -- local variables & parameters (default fg)
  local FIELD           = "#c77dbb" -- fields / properties (pink)
  local STATIC          = "#c77dbb" -- static members (italic)
  local CONST           = "#c77dbb" -- const / readonly
  local TYPE            = "#bcbec4" -- classes / types (default fg in Islands Dark)
  local KEYWORD         = "#cf8e6d" -- keywords
  local STRING          = "#6aab73" -- strings
  local NUMBER          = "#2aacb8" -- numeric literals
  local COMMENT         = "#7a7e85" -- comments (italic)
  local FUNCTION        = "#56a8f5" -- methods (blue)
  local NAMESPACE       = "#c77dbb" -- namespaces
  local INTERFACE       = "#c77dbb"
  local ENUM_MEMBER     = "#c77dbb"

  -- Local variables / parameters: blue (Rider-style).
  vim.api.nvim_set_hl(0, "@lsp.type.variable",                   { fg = VAR })
  vim.api.nvim_set_hl(0, "@lsp.type.parameter",                  { fg = VAR })

  -- Instance fields & properties: purple.
  vim.api.nvim_set_hl(0, "@lsp.type.field",                      { fg = FIELD })
  vim.api.nvim_set_hl(0, "@lsp.type.property",                   { fg = FIELD })

  -- Static modifier on anything: italic purple.
  vim.api.nvim_set_hl(0, "@lsp.typemod.variable.static",         { fg = STATIC, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.typemod.field.static",            { fg = STATIC, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.typemod.property.static",         { fg = STATIC, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.typemod.method.static",           { fg = FUNCTION, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.typemod.function.static",         { fg = FUNCTION, italic = true })

  -- Const / readonly: dim purple, italic.
  vim.api.nvim_set_hl(0, "@lsp.typemod.variable.readonly",       { fg = CONST, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.typemod.field.readonly",          { fg = CONST, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.typemod.property.readonly",       { fg = CONST, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.mod.readonly",                    { fg = CONST, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.mod.static",                      { italic = true })

  -- Types / classes / enums / interfaces / structs — italic fg in Rider.
  vim.api.nvim_set_hl(0, "@lsp.type.class",                      { fg = TYPE, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.type.struct",                     { fg = TYPE, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.type.enum",                       { fg = TYPE, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.type.interface",                  { fg = INTERFACE, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.type.type",                       { fg = TYPE, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.type.typeParameter",              { fg = TYPE, italic = true })
  vim.api.nvim_set_hl(0, "@lsp.type.enumMember",                 { fg = ENUM_MEMBER })

  -- Functions & methods (yellow in Darcula).
  vim.api.nvim_set_hl(0, "@lsp.type.function",                   { fg = FUNCTION })
  vim.api.nvim_set_hl(0, "@lsp.type.method",                     { fg = FUNCTION })
  -- Clear any language-specific overrides so the generic ones above win.
  for _, lang in ipairs({ "cs", "python", "rust", "c", "cpp", "lua", "typescript", "javascript" }) do
    for _, grp in ipairs({
      "@lsp.type.variable", "@lsp.type.parameter",
      "@lsp.type.field", "@lsp.type.property",
      "@lsp.type.function", "@lsp.type.method",
      "@lsp.type.class", "@lsp.type.struct", "@lsp.type.enum", "@lsp.type.interface",
      "@lsp.type.keyword", "@lsp.type.namespace",
    }) do
      vim.api.nvim_set_hl(0, grp .. "." .. lang, {})
    end
  end

  -- Keywords / namespaces.
  vim.api.nvim_set_hl(0, "@lsp.type.keyword",                    { fg = KEYWORD })
  vim.api.nvim_set_hl(0, "@lsp.type.namespace",                  { fg = NAMESPACE })
  vim.api.nvim_set_hl(0, "@lsp.type.macro",                      { fg = KEYWORD })

  -- Legacy Vim syntax groups (fallback when a buffer has no treesitter / LSP highlight).
  vim.api.nvim_set_hl(0, "Type",       { fg = TYPE })
  vim.api.nvim_set_hl(0, "Structure",  { fg = TYPE })
  vim.api.nvim_set_hl(0, "Identifier", { fg = VAR })
  vim.api.nvim_set_hl(0, "Function",   { fg = FUNCTION })
  vim.api.nvim_set_hl(0, "Statement",  { fg = KEYWORD })
  vim.api.nvim_set_hl(0, "Keyword",    { fg = KEYWORD })
  vim.api.nvim_set_hl(0, "Conditional",{ fg = KEYWORD })
  vim.api.nvim_set_hl(0, "Repeat",     { fg = KEYWORD })
  vim.api.nvim_set_hl(0, "String",     { fg = STRING })
  vim.api.nvim_set_hl(0, "Number",     { fg = NUMBER })
  vim.api.nvim_set_hl(0, "Constant",   { fg = CONST })
  vim.api.nvim_set_hl(0, "Comment",    { fg = COMMENT, italic = true })

  -- Treesitter fallbacks (for when LSP tokens aren't present).
  vim.api.nvim_set_hl(0, "@variable",                            { fg = VAR })
  vim.api.nvim_set_hl(0, "@variable.parameter",                  { fg = VAR })
  vim.api.nvim_set_hl(0, "@variable.member",                     { fg = FIELD })      -- fields
  vim.api.nvim_set_hl(0, "@parameter",                           { fg = VAR })
  vim.api.nvim_set_hl(0, "@field",                               { fg = FIELD })
  vim.api.nvim_set_hl(0, "@property",                            { fg = FG })          -- properties = plain fg
  vim.api.nvim_set_hl(0, "@constant",                            { fg = CONST })
  vim.api.nvim_set_hl(0, "@type",                                { fg = TYPE, italic = true })
  vim.api.nvim_set_hl(0, "@type.builtin",                        { fg = TYPE, italic = true })
  vim.api.nvim_set_hl(0, "@function",                            { fg = FUNCTION })
  vim.api.nvim_set_hl(0, "@function.method",                     { fg = FUNCTION })
  vim.api.nvim_set_hl(0, "@function.method.call",                { fg = FUNCTION })
  vim.api.nvim_set_hl(0, "@method",                              { fg = FUNCTION })
  vim.api.nvim_set_hl(0, "@keyword",                             { fg = KEYWORD })
  vim.api.nvim_set_hl(0, "@operator",                            { fg = FG })
  vim.api.nvim_set_hl(0, "@keyword.operator",                    { fg = FG })
  vim.api.nvim_set_hl(0, "Operator",                             { fg = FG })
  vim.api.nvim_set_hl(0, "@punctuation",                         { fg = FG })
  vim.api.nvim_set_hl(0, "@punctuation.bracket",                 { fg = FG })
  vim.api.nvim_set_hl(0, "@punctuation.delimiter",               { fg = FG })
  vim.api.nvim_set_hl(0, "@punctuation.special",                 { fg = FG })
  vim.api.nvim_set_hl(0, "Delimiter",                            { fg = FG })
  vim.api.nvim_set_hl(0, "@string",                              { fg = STRING })
  vim.api.nvim_set_hl(0, "@number",                              { fg = NUMBER })
  vim.api.nvim_set_hl(0, "@comment",                             { fg = COMMENT, italic = true })
end

-- --- Previous / tokyonight-storm defaults (for reference) ------------------
-- @lsp.type.variable          → fg #c0caf5 (default fg)
-- @lsp.type.parameter         → fg #e0af68 (orange)
-- @lsp.type.field             → fg #7dcfff (cyan)
-- @lsp.type.property          → fg #7dcfff (cyan)
-- @lsp.typemod.variable.static→ (no distinct style, falls through to @lsp.type.variable)
-- @lsp.typemod.*.readonly     → (no distinct style)
-- @lsp.type.class/struct/enum → fg #2ac3de
-- @lsp.type.interface         → fg #2ac3de
-- @lsp.type.function/method   → fg #7aa2f7
-- @lsp.type.keyword           → fg #9d7cd8 (purple)
-- @lsp.type.namespace         → fg #c0caf5
-- ---------------------------------------------------------------------------

vim.api.nvim_create_autocmd("ColorScheme", {
  group = user_hl_group,
  callback = apply_pycharm,
})
apply_pycharm()

-- No vim.lsp.enable() calls here: mason-lspconfig's automatic_enable turns on
-- every mason-installed server; servers outside mason are enabled in
-- lua/plugins/lsp.lua next to their config (e.g. lemminx).
