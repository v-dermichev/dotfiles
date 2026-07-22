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
    -- Patch out the two `redraw!` calls (drawer render + connect): a bang
    -- redraw clears and repaints the whole screen, visibly blinking every
    -- pane on each drawer toggle. They only serve to clear echo messages.
    -- Runs as a build step so the patch reapplies after plugin updates.
    build = [[sh -c "sed -i 's/^\s*redraw!$/  \" redraw! patched out: full-screen repaint blinks every pane/' autoload/db_ui/drawer.vim autoload/db_ui.vim"]],
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
          -- Placement contract lives in config.layout: drawer shares the
          -- tree's column (or sits left of the editor when the tree is off).
          -- Here: create/close the drawer in the right place, then normalize.
          local layout = require("config.layout")
          local drawer, tree
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
            if ft == "dbui" then drawer = w end
            if ft == "neo-tree" then tree = w end
          end
          if drawer then
            vim.cmd("DBUIClose")
          elseif tree then
            vim.api.nvim_set_current_win(tree)
            vim.cmd("belowright DBUI")
          else
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local b = vim.api.nvim_win_get_buf(w)
              if vim.api.nvim_win_get_config(w).relative == "" and vim.bo[b].buftype == "" then
                vim.api.nvim_set_current_win(w)
                break
              end
            end
            vim.cmd("aboveleft vertical DBUI")
          end
          layout.sync()
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

      -- Drawer: <leader>r on a saved query runs it WITHOUT any editor
      -- buffer: the query FILE is executed through a scratch buffer + %DB
      -- (dadbod captures the range synchronously; dbout docks via layout).
      -- Resolution: line label -> save_location/<conn-slug>/<label>.sql,
      -- url by matching the slug against vim.g.dbs + connections.json.
      -- Non-query lines fall back to plain SelectLine (toggle/expand).
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "dbui",
        callback = function(ev)
          vim.keymap.set("n", "<leader>r", function()
            local label = vim.api.nvim_get_current_line():match("([%w%._%-]+)%s*$")
            local path
            if label then
              local base = vim.g.db_ui_save_location
              path = vim.fn.glob(base .. "/*/" .. label, false, true)[1]
                or vim.fn.glob(base .. "/*/" .. label .. ".sql", false, true)[1]
            end
            if not path then
              vim.cmd([[execute "normal \<Plug>(DBUI_SelectLine)"]])
              return
            end
            local slug = vim.fn.fnamemodify(path, ":h:t")
            local url
            local function try(name, u)
              if not url and vim.fn["db_ui#utils#slug"](name) == slug then url = u end
            end
            local dbs = vim.g.dbs or {}
            if vim.islist and vim.islist(dbs) or dbs[1] then
              for _, d in ipairs(dbs) do try(d.name, d.url) end
            else
              for n, u in pairs(dbs) do try(n, u) end
            end
            if not url then
              local ok, conns = pcall(function()
                return vim.json.decode(table.concat(
                  vim.fn.readfile(vim.g.db_ui_save_location .. "/connections.json"), "\n"))
              end)
              if ok then
                for _, c in ipairs(conns or {}) do try(c.name, c.url) end
              end
            end
            if not url then
              vim.notify("DB: no connection found for " .. slug, vim.log.levels.WARN)
              return
            end
            local scratch = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(scratch, 0, -1, false, vim.fn.readfile(path))
            vim.api.nvim_buf_call(scratch, function()
              vim.cmd("%DB " .. vim.fn.fnameescape(url))
            end)
            vim.schedule(function()
              pcall(vim.api.nvim_buf_delete, scratch, { force = true })
            end)
            require("config.layout").sync()
          end, { buffer = ev.buf, desc = "DB: run query under cursor (no editor)" })
        end,
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
          -- Synchronous in the FileType tick so the results pane never
          -- flashes at the query-window split before jumping to the slot;
          -- the scheduled pass is an idempotent safety net for any path
          -- where the window doesn't exist yet at ft-set time.
          local function dock_results()
            pcall(function()
              local tt = require("config.term_tabs")
              local win
              for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if vim.api.nvim_win_get_buf(w) == ev.buf
                    and vim.api.nvim_win_get_config(w).relative == "" then
                  win = w
                  break
                end
              end
              if not win then return end
              local prev = vim.api.nvim_get_current_win()
              -- occupancy: exactly one slot pane. dadbod fires FileType twice
              -- per execution; once this buffer IS the registered "db" pane,
              -- clearing again would close our own window.
              local already_adopted = false
              for _, e in ipairs(tt._ext) do
                if e.key == "db" and e.buf == ev.buf then already_adopted = true end
              end
              if not already_adopted then
                tt.hide_all()
                tt.register_ext({
                  key = "db",
                  glyph = "\xef\x87\x80", -- nf-fa-database (U+F1C0)
                  label = "db",
                  buf = ev.buf,
                })
              end
              -- geometry: canonical layout handles the docking
              require("config.layout").apply()
              if vim.api.nvim_win_is_valid(prev) then
                pcall(vim.api.nvim_set_current_win, prev)
              end
            end)
          end
          dock_results()
          vim.schedule(dock_results)
        end,
      })
    end,
  },
}
