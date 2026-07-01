-- Telescope is kept only as neovim-project's picker (see project.lua); the
-- finder keymaps live on fzf-lua now (<leader>f*), so none are defined here.
return {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
}

