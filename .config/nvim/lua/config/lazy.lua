-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "plugins" }
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- Quietly check for updates in the background; the autocmd below applies them.
  checker = { enabled = true, notify = false },
})

-- Apply available plugin updates in the background, at most once per 24h.
-- The update runs silently after startup so it never blocks opening a file.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      local stamp = vim.fn.stdpath("state") .. "/lazy_last_autoupdate"
      local now = os.time()
      local last = 0
      local f = io.open(stamp, "r")
      if f then
        last = tonumber(f:read("*a")) or 0
        f:close()
      end
      if now - last < 24 * 60 * 60 then
        return
      end
      local w = io.open(stamp, "w")
      if w then
        w:write(tostring(now))
        w:close()
      end
      require("lazy").update({ show = false })
    end, 5000)
  end,
})
