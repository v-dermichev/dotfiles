-- pycharm-dark — a standalone colorscheme approximating JetBrains' "New UI"
-- Dark (PyCharm). Editor chrome + syntax + treesitter + LSP semantic tokens.
-- The semantic-token mapping mirrors the tuned `apply_pycharm()` palette in
-- init.lua, so the two stay consistent if both happen to run.

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "pycharm-dark"

local c = {
  bg         = "#1e1f22", -- editor background
  bg_alt     = "#2b2d30", -- panels, popups, statusline
  bg_sel     = "#214283", -- selection / pmenu sel
  visual     = "#2e436e",
  cursorline = "#26282e",
  fg         = "#bcbec4", -- default text
  fg_dim     = "#868a91",
  comment    = "#7a7e85",
  gutter     = "#4e5157",
  gutter_cur = "#a1a3ab",
  border     = "#393b40",
  paren      = "#43454a",
  nontext    = "#34373c",

  keyword    = "#cf8e6d", -- class/def/return/None/True/False
  string     = "#6aab73",
  number     = "#2aacb8",
  func       = "#56a8f5", -- function & method names
  field      = "#c77dbb", -- fields / properties / namespaces / enum members
  constant   = "#c77dbb",
  type       = "#bcbec4", -- classes / types (italic)
  selfkw     = "#c77dbb", -- self / cls
  decorator  = "#b3ae60", -- annotations / decorators (@property)

  error      = "#f75464",
  warn       = "#f2c55c",
  info       = "#3592c4",
  hint       = "#6aab73",
  add        = "#5fad65",
  change     = "#3592c4",
  delete     = "#f75464",
}

local function hl(group, opts) vim.api.nvim_set_hl(0, group, opts) end

-- ── Editor chrome ────────────────────────────────────────────────────────
hl("Normal",        { fg = c.fg, bg = c.bg })
hl("NormalNC",      { fg = c.fg, bg = c.bg })
hl("NormalFloat",   { fg = c.fg, bg = c.bg_alt })
hl("FloatBorder",   { fg = c.fg, bg = c.bg_alt })     -- match blink's (NormalFloat) border tone
hl("FloatTitle",    { fg = c.fg, bg = c.bg_alt, bold = true })
hl("ColorColumn",   { bg = "#26282c" }) -- faint line-length ruler
hl("Cursor",        { fg = c.bg, bg = c.fg })
hl("CursorLine",    { bg = c.cursorline })
hl("CursorColumn",  { bg = c.cursorline })
hl("CursorLineNr",  { fg = c.gutter_cur, bold = true })
hl("LineNr",        { fg = c.gutter })
hl("SignColumn",    { bg = c.bg })
hl("FoldColumn",    { fg = c.gutter, bg = c.bg })
hl("Folded",        { fg = c.comment, bg = c.bg_alt })
hl("VertSplit",     { fg = c.border })
hl("WinSeparator",  { fg = c.border })
hl("Visual",        { bg = c.visual })
hl("VisualNOS",     { bg = c.visual })
hl("Search",        { fg = c.bg, bg = "#b09650" })
hl("IncSearch",     { fg = c.bg, bg = c.keyword })
hl("CurSearch",     { fg = c.bg, bg = c.keyword })
hl("MatchParen",    { bg = c.paren, bold = true })
hl("Pmenu",         { fg = c.fg, bg = c.bg_alt })
hl("PmenuSel",      { fg = c.fg, bg = c.bg_sel })
hl("PmenuSbar",     { bg = c.bg_alt })
hl("PmenuThumb",    { bg = c.border })
hl("WildMenu",      { fg = c.fg, bg = c.bg_sel })
hl("StatusLine",    { fg = c.fg, bg = c.bg_alt })
hl("StatusLineNC",  { fg = c.comment, bg = c.bg_alt })
hl("TabLine",       { fg = c.comment, bg = c.bg_alt })
hl("TabLineSel",    { fg = c.fg, bg = c.bg })
hl("TabLineFill",   { bg = c.bg_alt })
hl("WinBar",        { fg = c.fg, bg = "#2b2d30" })
hl("WinBarNC",      { fg = c.comment, bg = "#2b2d30" })
hl("TermTabFill",   { bg = "#2b2d30" }) -- terminal tab-line background
hl("TermFileLink",  { fg = c.func, underline = true }) -- file:line:col links in terminals
hl("NonText",       { fg = c.nontext })
hl("Whitespace",    { fg = c.nontext })
hl("SpecialKey",    { fg = c.nontext })
hl("Conceal",       { fg = c.comment })
hl("Directory",     { fg = c.func })
hl("Title",         { fg = c.func, bold = true })
hl("ErrorMsg",      { fg = c.error })
hl("WarningMsg",    { fg = c.warn })
hl("Question",      { fg = c.string })
hl("MoreMsg",       { fg = c.string })
hl("ModeMsg",       { fg = c.fg })
hl("QuickFixLine",  { bg = c.bg_sel })
hl("LspInlayHint",  { fg = "#5b5e66", bg = "#26282e", italic = true })

-- ── Legacy syntax groups ─────────────────────────────────────────────────
hl("Comment",     { fg = c.comment, italic = true })
hl("Constant",    { fg = c.constant })
hl("String",      { fg = c.string })
hl("Character",   { fg = c.string })
hl("Number",      { fg = c.number })
hl("Float",       { fg = c.number })
hl("Boolean",     { fg = c.keyword })
hl("Identifier",  { fg = c.fg })
hl("Function",    { fg = c.func })
hl("Statement",   { fg = c.keyword })
hl("Conditional", { fg = c.keyword })
hl("Repeat",      { fg = c.keyword })
hl("Label",       { fg = c.keyword })
hl("Operator",    { fg = c.fg })
hl("Keyword",     { fg = c.keyword })
hl("Exception",   { fg = c.keyword })
hl("PreProc",     { fg = c.keyword })
hl("Include",     { fg = c.keyword })
hl("Define",      { fg = c.keyword })
hl("Macro",       { fg = c.keyword })
hl("Type",        { fg = c.type, italic = true })
hl("StorageClass",{ fg = c.keyword })
hl("Structure",   { fg = c.type, italic = true })
hl("Typedef",     { fg = c.type, italic = true })
hl("Special",     { fg = c.func })
hl("SpecialChar", { fg = c.number })
hl("Delimiter",   { fg = c.fg })
hl("Todo",        { fg = c.bg, bg = c.warn, bold = true })
hl("Error",       { fg = c.error })

-- ── Treesitter ───────────────────────────────────────────────────────────
hl("@variable",            { fg = c.fg })
hl("@variable.builtin",    { fg = c.selfkw, italic = true }) -- self / cls
hl("@variable.parameter",  { fg = c.fg })
hl("@variable.member",     { fg = c.field })                 -- instance fields
hl("@property",            { fg = c.field })
hl("@field",               { fg = c.field })
hl("@parameter",           { fg = c.fg })
hl("@constant",            { fg = c.constant })
hl("@constant.builtin",    { fg = c.keyword })               -- None / True / False
hl("@constant.macro",      { fg = c.constant })
hl("@module",              { fg = c.field })
hl("@namespace",           { fg = c.field })
hl("@string",              { fg = c.string })
hl("@string.documentation",{ fg = c.string, italic = true }) -- docstrings
hl("@string.escape",       { fg = c.number })
hl("@string.regexp",       { fg = c.number })
hl("@character",           { fg = c.string })
hl("@number",              { fg = c.number })
hl("@number.float",        { fg = c.number })
hl("@boolean",             { fg = c.keyword })
hl("@function",            { fg = c.func })
hl("@function.builtin",    { fg = c.func })
hl("@function.call",       { fg = c.func })
hl("@function.method",     { fg = c.func })
hl("@function.method.call",{ fg = c.func })
hl("@constructor",         { fg = c.func })
hl("@keyword",             { fg = c.keyword })
hl("@keyword.function",    { fg = c.keyword })
hl("@keyword.operator",    { fg = c.fg })
hl("@keyword.return",      { fg = c.keyword })
hl("@keyword.import",      { fg = c.keyword })
hl("@keyword.exception",   { fg = c.keyword })
hl("@operator",            { fg = c.fg })
hl("@punctuation.delimiter", { fg = c.fg })
hl("@punctuation.bracket",   { fg = c.fg })
hl("@punctuation.special",   { fg = c.number })
hl("@comment",             { fg = c.comment, italic = true })
hl("@comment.documentation", { fg = c.comment, italic = true })
hl("@type",                { fg = c.type, italic = true })
hl("@type.builtin",        { fg = c.type, italic = true })
hl("@type.definition",     { fg = c.type, italic = true })
hl("@attribute",           { fg = c.decorator })             -- @decorators
hl("@attribute.builtin",   { fg = c.decorator })
hl("@tag",                 { fg = c.keyword })
hl("@tag.attribute",       { fg = c.field })
hl("@tag.delimiter",       { fg = c.fg })

-- ── LSP semantic tokens (ty, lua_ls, …) ──────────────────────────────────
hl("@lsp.type.variable",   { fg = c.fg })
hl("@lsp.type.parameter",  { fg = c.fg })
hl("@lsp.type.property",   { fg = c.field })
hl("@lsp.type.field",      { fg = c.field })
hl("@lsp.type.function",   { fg = c.func })
hl("@lsp.type.method",     { fg = c.func })
hl("@lsp.type.class",      { fg = c.type, italic = true })
hl("@lsp.type.type",       { fg = c.type, italic = true })
hl("@lsp.type.struct",     { fg = c.type, italic = true })
hl("@lsp.type.enum",       { fg = c.type, italic = true })
hl("@lsp.type.interface",  { fg = c.field, italic = true })
hl("@lsp.type.typeParameter", { fg = c.type, italic = true })
hl("@lsp.type.enumMember",  { fg = c.constant })
hl("@lsp.type.namespace",   { fg = c.field })
hl("@lsp.type.keyword",     { fg = c.keyword })
hl("@lsp.type.decorator",   { fg = c.decorator })
hl("@lsp.type.selfParameter", { fg = c.selfkw, italic = true })
hl("@lsp.type.builtinConstant", { fg = c.keyword })
hl("@lsp.typemod.variable.readonly", { fg = c.constant, italic = true })
hl("@lsp.typemod.variable.static",   { fg = c.constant, italic = true })
hl("@lsp.typemod.property.readonly", { fg = c.constant, italic = true })
hl("@lsp.typemod.method.static",     { fg = c.func, italic = true })
hl("@lsp.typemod.function.builtin",  { fg = c.func })
hl("@lsp.mod.readonly",     { italic = true })

-- ── Diagnostics ──────────────────────────────────────────────────────────
hl("DiagnosticError", { fg = c.error })
hl("DiagnosticWarn",  { fg = c.warn })
hl("DiagnosticInfo",  { fg = c.info })
hl("DiagnosticHint",  { fg = c.hint })
hl("DiagnosticOk",    { fg = c.add })
hl("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hl("DiagnosticUnderlineWarn",  { undercurl = true, sp = c.warn })
hl("DiagnosticUnderlineInfo",  { undercurl = true, sp = c.info })
hl("DiagnosticUnderlineHint",  { undercurl = true, sp = c.hint })

-- ── Git / diff ───────────────────────────────────────────────────────────
hl("DiffAdd",    { bg = "#1d2b1f" })
hl("DiffChange", { bg = "#1b2733" })
hl("DiffDelete", { bg = "#2b1d1f" })
hl("DiffText",   { bg = "#284058" })
hl("Added",      { fg = c.add })
hl("Changed",    { fg = c.change })
hl("Removed",    { fg = c.delete })
hl("GitSignsAdd",    { fg = c.add })
hl("GitSignsChange", { fg = c.change })
hl("GitSignsDelete", { fg = c.delete })

-- ── A few plugin niceties ────────────────────────────────────────────────
hl("SnacksIndent",      { fg = "#2c2e33" })
hl("SnacksIndentScope", { fg = "#4a4d54" })
hl("IblIndent",         { fg = "#2c2e33" })
hl("IblScope",          { fg = "#4a4d54" })
hl("AerialLine",        { bg = c.cursorline })

-- satellite.nvim scrollbar: a soft grey thumb like PyCharm's, over a
-- transparent track, with overlay marks tinted from the diagnostic/git/search
-- palette so they read the same as their gutter/virtual-text counterparts.
hl("SatelliteBar",               { bg = c.paren })       -- thumb
hl("SatelliteBackground",        {})                     -- track (transparent)
hl("SatelliteCursor",            { fg = c.gutter_cur })
hl("SatelliteSearch",            { fg = "#b09650" })      -- matches Search
hl("SatelliteSearchCurrent",     { fg = c.keyword })      -- matches CurSearch
hl("SatelliteDiagnosticError",   { fg = c.error })
hl("SatelliteDiagnosticWarn",    { fg = c.warn })
hl("SatelliteDiagnosticInfo",    { fg = c.info })
hl("SatelliteDiagnosticHint",    { fg = c.hint })
hl("SatelliteGitSignsAdd",       { fg = c.add })
hl("SatelliteGitSignsChange",    { fg = c.change })
hl("SatelliteGitSignsDelete",    { fg = c.delete })
hl("SatelliteMark",              { fg = c.func })
hl("SatelliteQuickfix",          { fg = c.decorator })

-- ── Terminal ANSI palette ────────────────────────────────────────────────
vim.g.terminal_color_0  = "#27282b"
vim.g.terminal_color_1  = "#f75464"
vim.g.terminal_color_2  = "#6aab73"
vim.g.terminal_color_3  = "#cf8e6d"
vim.g.terminal_color_4  = "#56a8f5"
vim.g.terminal_color_5  = "#c77dbb"
vim.g.terminal_color_6  = "#2aacb8"
vim.g.terminal_color_7  = "#bcbec4"
vim.g.terminal_color_8  = "#5a5d63"
vim.g.terminal_color_9  = "#f75464"
vim.g.terminal_color_10 = "#6aab73"
vim.g.terminal_color_11 = "#cf8e6d"
vim.g.terminal_color_12 = "#56a8f5"
vim.g.terminal_color_13 = "#c77dbb"
vim.g.terminal_color_14 = "#2aacb8"
vim.g.terminal_color_15 = "#ffffff"
