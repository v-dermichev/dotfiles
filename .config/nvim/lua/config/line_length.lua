-- Draw a faint grey ruler (colorcolumn) at the recommended line length.
--
-- Source of truth, in order:
--   1. ruff's own E501 diagnostic ("Line too long (127 > 120)") — the exact
--      limit the LSP enforces, so the ruler always matches the linter.
--   2. `line-length` in ruff.toml / .ruff.toml / pyproject.toml (preferring
--      the [tool.ruff] section), or `max-line-length` in setup.cfg.
--   3. 'textwidth' (which Neovim's editorconfig support sets), as a fallback.

local M = {}

-- Read the limit straight from a ruff "line too long" diagnostic if present.
local function from_diagnostics(buf)
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    local limit = d.message and d.message:match("[Ll]ine too long %(%d+ > (%d+)%)")
    if limit then return tonumber(limit) end
  end
  return nil
end

-- Parse a config file's line length, tracking [section] headers so we prefer
-- ruff's value over other tools that set their own (black/isort/flake8).
local function parse_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end
  local section = ""
  local by_section = {}
  for _, line in ipairs(lines) do
    local sec = line:match("^%s*%[%s*([^%]]-)%s*%]")
    if sec then section = sec end
    local n = line:match("^%s*line%-length%s*=%s*(%d+)")
      or line:match("^%s*max%-line%-length%s*=%s*(%d+)")
      or line:match("^%s*max_line_length%s*=%s*(%d+)")
    if n then by_section[section] = tonumber(n) end
  end
  local pick = by_section["tool.ruff"]
    or by_section["tool.ruff.lint"]
    or by_section["tool.black"]
    or by_section[""]
    or by_section["flake8"]
    or by_section["pycodestyle"]
  if pick then return pick end
  local _, any = next(by_section)
  return any
end

local function project_length(buf)
  local file = vim.api.nvim_buf_get_name(buf)
  local dir = (file ~= "" and vim.fs.dirname(file)) or vim.fn.getcwd()
  for _, name in ipairs({ "ruff.toml", ".ruff.toml", "pyproject.toml", "setup.cfg" }) do
    local hit = vim.fs.find(name, { path = dir, upward = true, type = "file" })[1]
    if hit then
      local n = parse_file(hit)
      if n then return n end
    end
  end
  return nil
end

local function compute(buf)
  local n = from_diagnostics(buf) or project_length(buf)
  if not n and (vim.bo[buf].textwidth or 0) > 0 then
    n = vim.bo[buf].textwidth
  end
  return n
end

-- Set colorcolumn on every window currently showing `buf`.
function M.apply(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" then return end
  local cc = compute(buf)
  cc = cc and tostring(cc) or ""
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    vim.wo[win].colorcolumn = cc
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("LineLengthRuler", { clear = true })
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter", "LspAttach", "DiagnosticChanged" }, {
    group = group,
    callback = function(ev)
      M.apply(ev.buf)
    end,
  })
end

return M
