return {
  "ibhagwan/fzf-lua",
  enabled = true,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- Defer past UI startup; the keymaps below are registered when it loads.
  event = "VeryLazy",
  config = function()
    local map = vim.keymap;
    local options = {};
    local fzf = require('fzf-lua')

    fzf.setup({
      winopts = { preview = { layout = "vertical" } }
    }
    )

    -- LSP navigation (g-prefixed; already comfortable, left as-is).
    map.set('n', 'gd', fzf.lsp_definitions, { desc = "Go to definition" })
    map.set('n', 'gD', fzf.lsp_declarations, { desc = "Go to declaration" })
    map.set('n', 'gI', fzf.lsp_implementations, { desc = "Go to implementation" })
    map.set('n', 'gy', fzf.lsp_typedefs, { desc = "Go to type definition" })
    map.set('n', 'gr', fzf.lsp_references, { desc = "References" })

    -- Pickers — leader-based (fzf is the single finder; telescope keeps
    -- only its role as neovim-project's picker).
    map.set('n', '<leader>ff', fzf.files, { desc = "Find files" })
    map.set('n', '<leader>fg', fzf.live_grep, { desc = "Live grep (project)" })
    map.set('n', '<leader>fb', fzf.buffers, { desc = "Buffers" })
    map.set('n', '<leader>fl', fzf.grep_curbuf, { desc = "Grep current buffer" })
    map.set('n', '<leader>fh', fzf.helptags, { desc = "Help tags" })
    map.set('n', '<leader>fr', fzf.resume, { desc = "Resume last picker" })
    map.set('n', '<leader>fd', function()
      fzf.lsp_workspace_diagnostics({ severity_limit = 2 })       -- warning+
    end, { desc = "Workspace diagnostics" })
    map.set('n', '<leader>ca', fzf.lsp_code_actions, { desc = "Code actions" })

    fzf.register_ui_select();
  end
}
