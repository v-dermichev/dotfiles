-- Auto-activate a project's `.venv` when entering a directory that has one.
--
-- Detection runs on VimEnter and on every DirChanged (so it follows
-- neovim-project / :cd into a different project). Activation exports
-- $VIRTUAL_ENV and prepends `.venv/bin` to $PATH, which is exactly what
-- `ty` and `ruff` read to pick the right interpreter. Python language
-- servers already attached are restarted so they re-resolve the env.

local M = {}

-- The venv we currently have wired into the environment, so repeated
-- DirChanged events don't stack duplicate entries onto $PATH.
local active = nil

local SEP = vim.fn.has("win32") == 1 and ";" or ":"
local BIN = vim.fn.has("win32") == 1 and "Scripts" or "bin"

local function path_without(bin)
  local kept = {}
  for _, p in ipairs(vim.split(vim.env.PATH or "", SEP, { plain = true })) do
    if p ~= bin and p ~= "" then
      kept[#kept + 1] = p
    end
  end
  return table.concat(kept, SEP)
end

local function reload_python_lsp()
  local has_python = false
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name == "ty" or client.name == "ruff" then
      has_python = true
      break
    end
  end
  if has_python then
    -- :LspRestart (from nvim-lspconfig) re-launches with the new env.
    vim.schedule(function()
      pcall(vim.cmd, "LspRestart ty ruff")
    end)
  end
end

function M.deactivate()
  if not active then
    return
  end
  vim.env.PATH = path_without(active .. "/" .. BIN)
  vim.env.VIRTUAL_ENV = nil
  active = nil
end

function M.activate(venv)
  if active == venv then
    return
  end
  M.deactivate()
  vim.env.VIRTUAL_ENV = venv
  vim.env.PATH = venv .. "/" .. BIN .. SEP .. (vim.env.PATH or "")
  active = venv
  vim.schedule(function()
    vim.notify("venv → " .. vim.fn.fnamemodify(venv, ":~"), vim.log.levels.INFO)
  end)
  reload_python_lsp()
end

function M.detect(dir)
  dir = dir or vim.fn.getcwd()
  local hit = vim.fs.find(".venv", { path = dir, upward = true, type = "directory" })[1]
  if hit then
    M.activate(vim.fn.fnamemodify(hit, ":p"):gsub("[/\\]$", ""))
  else
    M.deactivate()
  end
end

function M.setup()
  -- Resolve the venv for the launch directory immediately, before lazy
  -- loads lspconfig and ty/ruff attach to the first buffer. This way the
  -- servers start already pointed at the venv, so go-to-definition resolves
  -- third-party packages on the very first try (no attach → restart race).
  M.detect()

  local group = vim.api.nvim_create_augroup("VenvAutoActivate", { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
    group = group,
    callback = function()
      M.detect(vim.fn.getcwd())
    end,
  })
end

return M
