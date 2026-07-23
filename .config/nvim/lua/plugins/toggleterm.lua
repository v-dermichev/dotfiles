---@type LazySpec
return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec", "ToggleTermToggleAll" },
  keys = {
    { [[<C-\>]], function() require("config.term_tabs").toggle() end, mode = { "n", "t" }, desc = "Terminal: toggle" },

    -- Numbered terminal "tabs" — swap in place, state preserved. Normal-mode
    -- only: a terminal-mode <leader> (space) map stalls every spacebar press for
    -- `timeoutlen` while nvim waits for the rest of the sequence. In terminal
    -- mode use <C-h>/<C-l> to cycle, or <Esc> then <leader>T#.
    { "<leader>T1", function() require("config.term_tabs").show(1) end, desc = "Terminal tab 1" },
    { "<leader>T2", function() require("config.term_tabs").show(2) end, desc = "Terminal tab 2" },
    { "<leader>T3", function() require("config.term_tabs").show(3) end, desc = "Terminal tab 3" },
    { "<leader>T4", function() require("config.term_tabs").show(4) end, desc = "Terminal tab 4" },
    { "<leader>T5", function() require("config.term_tabs").show(5) end, desc = "Terminal tab 5" },

    -- New / lazygit (cycling is bound buffer-locally to <C-h>/<C-l> inside terminals).
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
    shade_terminals = true,
    start_in_insert = true,
    -- Don't force-scroll to bottom on every output chunk: it fights scrolling
    -- up while a command is still printing. Nvim's native follow still applies
    -- (cursor on the last line follows output; scroll up to unpin, G to repin).
    auto_scroll = false,
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
        -- Escape, pane nav, tab cycling, and gf / Ctrl-click file:line:col
        -- links — the same set the slot's debug/test panes get.
        require("config.term_tabs").apply_term_local_maps(0)
        -- Terminal tab list winbar — gated behind term_tabs.tabbar.
        require("config.term_tabs").apply_winbar(0)
      end,
    })
  end,
}
