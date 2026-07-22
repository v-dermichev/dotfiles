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

-- Plugins that load files via bufadd/bufload (solution scanners, link
-- openers) skip filetype detection, and nvim never re-runs it when the
-- buffer is merely displayed later — leaving it with no ft, so no
-- treesitter/LSP/highlighting (repeatedly seen on csproj members of a slnx).
-- Detect on first display of any undetected file buffer.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("DetectBufloadedFiletype", { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].buftype == "" and vim.bo[ev.buf].filetype == ""
        and vim.api.nvim_buf_get_name(ev.buf) ~= "" then
      vim.api.nvim_buf_call(ev.buf, function() vim.cmd("filetype detect") end)
    end
  end,
})

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

-- All vim options live in lua/config/options.lua (required above).

-- Colorscheme (past experiments live in git history of this line).
vim.cmd.colorscheme("pycharm-dark")

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

  -- XML / markup tags (csproj, slnx, axaml, html). Islands Dark values:
  -- XML_TAG / XML_TAG_NAME / XML_PROLOGUE = #d5b778 (gold, incl. <> brackets),
  -- XML_ATTRIBUTE_NAME = default fg, XML_ENTITY_REFERENCE = #56a8f5.
  -- Attribute values / tag text inherit string green / default fg.
  local TAGC = "#d5b778"
  vim.api.nvim_set_hl(0, "@tag",                                 { fg = TAGC })
  vim.api.nvim_set_hl(0, "@tag.builtin",                         { fg = TAGC })
  vim.api.nvim_set_hl(0, "@tag.delimiter",                       { fg = TAGC })
  vim.api.nvim_set_hl(0, "@tag.attribute",                       { fg = FG })
  vim.api.nvim_set_hl(0, "@character.special.xml",               { fg = "#56a8f5" })
  -- Semantic tokens outrank treesitter, and roslyn/easy-dotnet tokenize csproj
  -- buffers: element names arrive as @lsp.type.class.xml and would take the
  -- C# type styling (plain fg + italic). Repaint the xml-suffixed groups with
  -- the XML palette so tags stay gold.
  vim.api.nvim_set_hl(0, "@lsp.type.class.xml",                  { fg = TAGC })
  vim.api.nvim_set_hl(0, "@lsp.type.property.xml",               { fg = FG })
  vim.api.nvim_set_hl(0, "@lsp.type.variable.xml",               { fg = FG })

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
