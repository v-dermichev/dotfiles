return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require("lualine").setup({
      options = {
        theme = "auto",     -- "auto" will set the theme dynamically based on the colorscheme
      },
      sections = {
        -- default x-section plus live NuGet operation progress (config/nuget.lua)
        lualine_x = {
          function() return require("config.nuget").statusline() end,
          "encoding", "fileformat", "filetype",
        },
      },
    })
  end
}
