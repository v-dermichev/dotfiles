return {
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- Enable true colors
      vim.opt.termguicolors = true

      -- Setup cyberdream with transparency
      require("cyberdream").setup({
        transparent = true,      -- important for letting terminal bg show through
        saturation = 1.0,
        italic_comments = false,
        hide_fillchars = false,
        extensions = {
          telescope = true,
          notify = true,
          mini = true,
          -- and so on, whatever you want enabled
        },
      })

      -- Apply the theme
      vim.cmd.colorscheme("cyberdream")

      -- Make highlight groups transparent
      for _, group in ipairs({
        "Normal", "NormalNC", "NonText", "LineNr",
        "SignColumn", "VertSplit", "StatusLine", "StatusLineNC",
        "Pmenu", "PmenuSel", "NormalFloat",
      }) do
        vim.api.nvim_set_hl(0, group, { bg = "none" })
      end
    end,
  },

  -- other plugins …
}

