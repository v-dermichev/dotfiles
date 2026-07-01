-- PyCharm-style `# language=<lang>` injection.
--
-- A comment like `# language=sql` on the line above a string highlights that
-- string as <lang> (the parser must be installed). Python comments are `extra`
-- treesitter nodes — hoisted out of the sibling sequence — so an injection query
-- can't match "comment directly above string" structurally. Instead a directive
-- reads the comment line above the string literal directly.
--
-- Used by after/queries/python/injections.scm.

local M = {}

-- `language=<alias>` → canonical treesitter parser / LSP name.
local ALIASES = {
  js = "javascript",
  ts = "typescript",
  sh = "bash",
  shell = "bash",
}

function M.setup()
  vim.treesitter.query.add_directive("inject-lang-from-comment!", function(match, _, bufnr, pred, metadata)
    local node = match[pred[2]]
    if type(node) == "table" then node = node[1] end
    if not node then return end
    -- Use the string literal's first line (handles triple-quoted strings whose
    -- content starts a line below the opening quotes).
    while node:parent() and node:type() ~= "string" do node = node:parent() end
    local row = node:range()
    -- Walk up through the comment block above the string (comments + blank
    -- lines); the `# language=<lang>` line may be anywhere in it. Stop at the
    -- first real code line.
    for r = row - 1, math.max(row - 40, 0), -1 do
      local line = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
      if not line then break end
      local lang = line:match("^%s*#%s*language=([%w_]+)")
      if lang then
        metadata["injection.language"] = ALIASES[lang] or lang
        return
      end
      if line:match("%S") and not line:match("^%s*#") then return end -- hit code
    end
  end, { force = true })

  -- Let treesitter own string highlighting so `# language=X` injections are
  -- visible: LSP semantic tokens paint the whole string as @string at priority
  -- 125 (above treesitter's 100), which otherwise repaints injected strings
  -- flat. Clearing the base group makes the string semantic token a no-op;
  -- normal strings are unchanged (treesitter's @string is the same colour).
  local function free_string_semantics()
    vim.api.nvim_set_hl(0, "@lsp.type.string", {})
  end
  vim.api.nvim_create_autocmd("ColorScheme", { callback = free_string_semantics })
  free_string_semantics()
end

return M
