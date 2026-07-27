-- Telescope is kept only as neovim-project's picker (see project.lua); the
-- finder keymaps live on fzf-lua now (<leader>f*), so none are defined here.
return {
  'nvim-telescope/telescope.nvim',
  branch = '0.1.x',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = function()
    local actions = require('telescope.actions')
    return {
      defaults = {
        mappings = {
          i = {
            ['<C-j>'] = actions.move_selection_next,
            ['<C-k>'] = actions.move_selection_previous,
          },
          n = {
            ['<C-j>'] = actions.move_selection_next,
            ['<C-k>'] = actions.move_selection_previous,
          },
        },
      },
    }
  end,
}
