return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require("lualine").setup({
      options = {
        theme = "auto", -- "auto" will set the theme dynamically based on the colorscheme
        -- One global bar at the very bottom (laststatus=3): individual panes
        -- (tree, DB drawer, terminal slot) never carry a statusline of their
        -- own, and horizontal pane boundaries are real WinSeparators with
        -- proper junction characters.
        globalstatus = true,
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
