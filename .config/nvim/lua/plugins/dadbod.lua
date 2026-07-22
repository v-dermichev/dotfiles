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

      -- Project-scoped connections without a dotenv plugin: dadbod-ui only
      -- reads DB_UI_* from the process environment, so a project .env file is
      -- invisible to it. Parse DB_UI_<NAME>=<url> lines from the cwd's .env
      -- (and .env.local) ourselves and publish them via vim.g.dbs — refreshed
      -- on startup, project switch and :cd. DBUIAddConnection entries stay
      -- global; these live with the project and are not written anywhere.
      -- On MariaDB systems /usr/bin/mysql is a deprecated compat shim that
      -- prints a warning on stderr, which breaks dadbod's mysql adapter.
      -- Detect it once; mysql:// urls are then routed to dadbod's mariadb
      -- adapter (same url grammar, drives the `mariadb` binary directly).
      local mariadb_shim
      local function mysql_is_mariadb()
        if mariadb_shim == nil then
          mariadb_shim = vim.fn.executable("mariadb") == 1
            and (vim.fn.executable("mysql") == 0
              or (vim.fn.system({ "mysql", "--version" }) or ""):find("MariaDB", 1, true) ~= nil)
        end
        return mariadb_shim
      end

      -- Unquote and adapt a connection url for this machine (mariadb shim,
      -- local self-signed certs — see the comments at each step).
      local function normalize_url(url)
        url = url:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        if url:match("^mysql://") and mysql_is_mariadb() then
          url = "mariadb://" .. url:sub(#"mysql://" + 1)
        end
        -- MariaDB client 11.4+ verifies server certs by default and refuses
        -- the self-signed ones local/docker dev servers use (ERROR 2026).
        -- For local connections, keep TLS but drop the verification — unless
        -- the url already carries params.
        local host = url:match("^m[%w]+://[^@/]*@([^:/?]+)")
        if (host == "localhost" or host == "127.0.0.1")
            and (url:match("^mariadb://") or url:match("^mysql://"))
            and not url:find("?", 1, true) then
          url = url .. "?ssl-verify-server-cert=off"
        end
        return url
      end

      -- ADO.NET-style connection strings ("Server=..;Port=..;Database=..;
      -- Uid=..;Pwd=..", the .NET convention) converted to the url dadbod
      -- expects. Returns nil when the value doesn't look like one.
      local function ado_to_url(s)
        if s:match("^[%w+]+://") or not s:find("=") then return nil end
        local kv = {}
        for pair in s:gmatch("[^;]+") do
          local k, v = pair:match("^%s*([%w%s]-)%s*=%s*(.-)%s*$")
          if k and k ~= "" then kv[k:lower():gsub("%s+", " ")] = v end
        end
        local host = kv["server"] or kv["host"] or kv["data source"]
        if not host then return nil end
        local user = kv["uid"] or kv["user id"] or kv["username"] or kv["user"]
        local pass = kv["pwd"] or kv["password"]
        local port = kv["port"]
        local db = kv["database"] or kv["initial catalog"]
        -- scheme heuristics: default mysql (this machine's stack); well-known
        -- ports / windows-auth keys override
        local scheme = "mysql"
        if port == "5432" then
          scheme = "postgresql"
        elseif port == "1433" or kv["trusted_connection"] or kv["integrated security"] then
          scheme = "sqlserver"
        end
        local function enc(x)
          return (x:gsub("[^%w%-%._~]", function(c) return ("%%%02X"):format(c:byte()) end))
        end
        local auth = user and (enc(user) .. (pass and ":" .. enc(pass) or "") .. "@") or ""
        return scheme .. "://" .. auth .. host .. (port and ":" .. port or "") .. "/" .. (db or "")
      end

      local function load_project_dbs()
        local dbs = {}
        for _, envname in ipairs({ ".env", ".env.local" }) do
          local ok, env_lines = pcall(vim.fn.readfile, vim.uv.cwd() .. "/" .. envname)
          if ok then
            for _, l in ipairs(env_lines) do
              local name, raw = l:match("^%s*e?x?p?o?r?t?%s*DB_UI_([%w_]+)%s*=%s*(.-)%s*$")
              if not raw then
                raw = l:match("^%s*e?x?p?o?r?t?%s*DATABASE_URL%s*=%s*(.-)%s*$")
              end
              if raw and raw ~= "" then
                local url = raw:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
                url = ado_to_url(url) or url
                url = normalize_url(url)
                if not name then
                  -- the app's own connection var doubles as a dev connection;
                  -- name it after the database in the url path
                  name = url:match("://[^/]+/([%w_%-]+)") or "env"
                end
                table.insert(dbs, { name = name:lower(), url = url })
              end
            end
          end
        end
        vim.g.dbs = dbs
      end

      load_project_dbs()
      vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
        group = group,
        callback = load_project_dbs,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "SessionLoadPost", -- neovim-project switch
        callback = load_project_dbs,
      })

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
