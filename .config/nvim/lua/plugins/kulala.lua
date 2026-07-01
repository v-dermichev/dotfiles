-- Kulala — an in-editor REST/HTTP client (à la JetBrains' HTTP client).
-- Requests live in `.http` / `.rest` buffers; `<leader>R` is the command menu
-- (which-key reveals the full set once a .http file is open). Project-scoped,
-- private collections can live in a `.kulala/` folder, which is git-ignored
-- globally (see ~/.gitignore_global) so they're never committed by accident.
return {
  "mistweaverco/kulala.nvim",
  ft = "http",
  init = function()
    -- Make sure .http/.rest open with the filetype kulala loads on.
    vim.filetype.add({ extension = { http = "http", rest = "http" } })
  end,
  opts = {
    -- Maintained keymap set under <leader>R (send / inspect / replay /
    -- copy-as-curl / env select / scratchpad / toggle view / …).
    global_keymaps = true,
    global_keymaps_prefix = "<leader>R",
    ui = {
      display_mode = "split",        -- response opens in a split, not a float
      split_direction = "vertical",
      default_view = "body",         -- show the response body first
    },
  },
}
