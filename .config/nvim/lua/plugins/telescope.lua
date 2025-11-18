return {
    'nvim-telescope/telescope.nvim', 
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
        local builtin = require('telescope.builtin')

        local opts = { noremap = true, silent = true }

        -- correct usage: pass opts table as is, not unpacked
        vim.keymap.set('n', '<leader>ff', builtin.find_files, vim.tbl_extend("force", { desc = 'Telescope find files' }, opts))
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, vim.tbl_extend("force", { desc = 'Telescope live grep' }, opts))
        vim.keymap.set('n', '<leader>fb', builtin.buffers, vim.tbl_extend("force", { desc = 'Telescope buffers' }, opts))
        vim.keymap.set('n', '<leader>fh', builtin.help_tags, vim.tbl_extend("force", { desc = 'Telescope help tags' }, opts))
    end
}

