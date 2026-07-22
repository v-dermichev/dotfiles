-- Database work pipeline: vim-dadbod (engine) + dadbod-ui (drawer, saved
-- queries, connections) + dadbod-completion (schema-aware completion).
--
-- Flow: <leader>q opens the drawer → pick/add a connection (DBUIAddConnection,
-- or per-project via vim.g.dbs / .env DATABASE_URL) → open a query buffer →
-- <leader>r (or :w) executes → results land in a `dbout` buffer that is also
-- adopted as a "db" tab in the shared bottom slot (term_tabs), next to the
-- terminals / debug / tests panes.
return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      {
        "kristijanhusak/vim-dadbod-completion",
        ft = { "sql", "mysql", "plsql" },
        lazy = true,
      },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer", "DB" },
    keys = {
      { "<leader>q", "<cmd>DBUIToggle<cr>", desc = "DB: toggle query UI" },
    },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
      -- :w in a query buffer executes it (the core query→output loop);
      -- <leader>r below does the same without writing.
      vim.g.db_ui_execute_on_save = 1

      local group = vim.api.nvim_create_augroup("DadbodPipeline", { clear = true })

      -- Query buffers: <leader>r runs the statement (normal: whole buffer /
      -- visual: selection) — mirrors the global "<leader>r runs current file".
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "sql", "mysql", "plsql" },
        callback = function(ev)
          vim.keymap.set("n", "<leader>r", "<Plug>(DBUI_ExecuteQuery)",
            { buffer = ev.buf, desc = "DB: execute query" })
          vim.keymap.set("v", "<leader>r", "<Plug>(DBUI_ExecuteQuery)",
            { buffer = ev.buf, desc = "DB: execute selection" })
        end,
      })

      -- Adopt the results buffer as a "db" tab in the shared bottom slot
      -- (display-level adoption like octo/neotest — dadbod keeps managing the
      -- window; the tab re-shows the latest results after it's been hidden).
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "dbout",
        callback = function(ev)
          vim.schedule(function()
            pcall(function()
              require("config.term_tabs").register_ext({
                key = "db",
                glyph = "\xef\x87\x80", -- nf-fa-database (U+F1C0)
                label = "db",
                buf = ev.buf,
              })
            end)
          end)
        end,
      })
    end,
  },
}
