---@type LazySpec
return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec", "ToggleTermToggleAll" },
  keys = {
    { [[<C-\>]], function() require("config.term_tabs").toggle() end, mode = { "n", "t" }, desc = "Terminal: toggle" },

    -- Numbered terminal "tabs" — swap in place, state preserved.
    { "<leader>T1", function() require("config.term_tabs").show(1) end, mode = { "n", "t" }, desc = "Terminal tab 1" },
    { "<leader>T2", function() require("config.term_tabs").show(2) end, mode = { "n", "t" }, desc = "Terminal tab 2" },
    { "<leader>T3", function() require("config.term_tabs").show(3) end, mode = { "n", "t" }, desc = "Terminal tab 3" },
    { "<leader>T4", function() require("config.term_tabs").show(4) end, mode = { "n", "t" }, desc = "Terminal tab 4" },
    { "<leader>T5", function() require("config.term_tabs").show(5) end, mode = { "n", "t" }, desc = "Terminal tab 5" },

    -- New / lazygit (cycling is bound buffer-locally to <S-h>/<S-l> inside terminals).
    { "<leader>Tn", function() require("config.term_tabs").new()     end, desc = "Terminal: new tab" },
    { "<leader>Tg", function() require("config.term_tabs").lazygit() end, desc = "Terminal: lazygit" },

    -- Layout variants (non-tab terminals).
    { "<leader>Tf", "<cmd>ToggleTerm direction=float<cr>",            desc = "Terminal: float" },
    { "<leader>Tv", "<cmd>ToggleTerm direction=vertical size=80<cr>", desc = "Terminal: vertical" },
  },
  opts = {
    size = function(term)
      if term.direction == "horizontal" then return 12
      elseif term.direction == "vertical" then return vim.o.columns * 0.4 end
    end,
    open_mapping = [[<C-\>]],
    shade_terminals = true,
    start_in_insert = true,
    persist_size = true,
    persist_mode = true,
    direction = "horizontal",
    close_on_exit = true,
  },
  config = function(_, opts)
    require("toggleterm").setup(opts)

    -- Terminal-buffer-local setup: escape, pane nav, tab cycling, winbar.
    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "term://*toggleterm#*",
      callback = function()
        local o = { buffer = 0 }
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]],        o)
        vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], o)
        vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], o)
        vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], o)
        vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], o)

        -- Cycle between terminal tabs, both in terminal and normal mode inside the terminal buffer.
        for _, mode in ipairs({ "n", "t" }) do
          vim.keymap.set(mode, "<S-h>", function() require("config.term_tabs").cycle(-1) end,
            { buffer = 0, desc = "Terminal: prev tab" })
          vim.keymap.set(mode, "<S-l>", function() require("config.term_tabs").cycle(1) end,
            { buffer = 0, desc = "Terminal: next tab" })
        end

        -- Show the terminal tab list as a winbar.
        vim.wo.winbar = "%!v:lua.require('config.term_tabs').winbar()"
      end,
    })
  end,
}
