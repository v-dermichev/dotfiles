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
      {
        "<leader>q",
        function()
          vim.cmd("DBUIToggle")
          -- Share the left column with neo-tree instead of adding a second
          -- sidebar: split the tree horizontally and dock the drawer below it.
          vim.schedule(function()
            local drawer, tree
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
              if ft == "dbui" then drawer = w end
              if ft == "neo-tree" then tree = w end
            end
            if drawer and tree then
              pcall(vim.fn.win_splitmove, drawer, tree, { rightbelow = true })
              local total = vim.api.nvim_win_get_height(tree) + vim.api.nvim_win_get_height(drawer)
              pcall(vim.api.nvim_win_set_height, drawer, math.floor(total / 2))
            end
          end)
        end,
        desc = "DB: toggle query UI",
      },
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

      -- Adopt the results buffer as the "db" tab of the shared bottom slot.
      -- Full takeover (unlike octo's display-level adoption): dadbod creates a
      -- NEW dbout buffer per execution and splits wherever the query window
      -- is, which piled up extra panes next to whatever the slot showed.
      -- Hide the slot's current occupant (incl. the previous results pane,
      -- via its stale "db" registration), then dock this one full-width.
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "dbout",
        callback = function(ev)
          vim.schedule(function()
            pcall(function()
              local tt = require("config.term_tabs")
              local prev = vim.api.nvim_get_current_win()
              -- clear the slot BEFORE registering: the old "db" registration
              -- still points at the previous results pane so it gets closed
              -- too; this dbout's window isn't registered yet and survives
              tt.hide_all()
              tt.register_ext({
                key = "db",
                glyph = "\xef\x87\x80", -- nf-fa-database (U+F1C0)
                label = "db",
                buf = ev.buf,
              })
              local win
              for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_get_buf(w) == ev.buf
                    and vim.api.nvim_win_get_config(w).relative == "" then
                  win = w
                  break
                end
              end
              if win then
                vim.api.nvim_win_call(win, function() vim.cmd("wincmd J") end)
                pcall(vim.api.nvim_win_set_height, win, 12)
              end
              if vim.api.nvim_win_is_valid(prev) then
                pcall(vim.api.nvim_set_current_win, prev)
              end
            end)
          end)
        end,
      })
    end,
  },
}
