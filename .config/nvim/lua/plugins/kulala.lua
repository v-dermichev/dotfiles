-- Kulala — an in-editor REST/HTTP client (à la JetBrains' HTTP client).
-- Requests live in `.http` / `.rest` buffers; `<leader>R` is the command menu
-- (which-key reveals the full set once a .http file is open). Project-scoped,
-- private collections can live in a `.kulala/` folder, which is git-ignored
-- globally (see ~/.gitignore_global) so they're never committed by accident.
return {
  "mistweaverco/kulala.nvim",
  ft = "http",
  keys = {
    -- Scaffold a ready-to-fill request in <project>/.kulala/. Available
    -- everywhere (lazy loads kulala on first press); N is free in kulala's
    -- <leader>R submenu.
    {
      "<leader>RN",
      function()
        local root = vim.fs.root(0, { ".git", "pyproject.toml", "setup.py", "Cargo.toml", ".kulala" })
          or vim.fn.getcwd()
        local dir = root .. "/.kulala"
        vim.fn.mkdir(dir, "p")
        vim.ui.input({ prompt = "New .http request name: ", default = "request" }, function(name)
          if not name or name:match("^%s*$") then return end
          name = name:gsub("%s+", "-"):gsub("[^%w%-_.]", "")
          local path = dir .. "/" .. name .. ".http"
          if vim.fn.filereadable(path) == 0 then
            vim.fn.writefile({
              "@baseUrl = https://api.example.com",
              "@token = ",
              "",
              "### " .. name,
              "# @name " .. name,
              "POST {{baseUrl}}/endpoint",
              "Content-Type: application/json",
              "Accept: application/json",
              "Authorization: Bearer {{token}}",
              "",
              "{",
              '  "key": "value"',
              "}",
              "",
            }, path)
          end
          vim.cmd.edit(vim.fn.fnameescape(path))
        end)
      end,
      desc = "Kulala: new request in <project>/.kulala",
    },
  },
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
