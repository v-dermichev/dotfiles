-- snacks.nvim is already pulled in (neovim-project depends on it); this
-- spec just turns on the indent-guide module. Other snacks modules stay
-- at their defaults so nothing else changes behaviour.
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    indent = {
      enabled = true,
      indent = { char = "│" },
      scope = { enabled = true, char = "│" },
      animate = { enabled = false },
    },
  },
}
