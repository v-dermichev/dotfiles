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
    --
    -- Upstream stays updatable: lazy's plain `git checkout` refuses dirty
    -- trees, so the LazyUpdatePre/RestorePre hooks below restore pristine
    -- files first, and the post hooks re-apply the (idempotent) sed. The
    -- build step covers fresh installs.
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
      -- Update/Delete scaffolds in each table's helper list. They contain
      -- <placeholders>, so the drawer <leader>r opens them for editing
      -- instead of executing (auto_execute stays off by default too).
      local scaffolds = {
        ["Insert row"] = "INSERT INTO {optional_schema}`{table}` (<columns>) VALUES (<values>);",
        ["Update rows"] = "UPDATE {optional_schema}`{table}` SET <col> = <value> WHERE <condition>;",
        ["Delete rows"] = "DELETE FROM {optional_schema}`{table}` WHERE <condition>;",
      }
      vim.g.db_ui_table_helpers = {
        mysql = scaffolds,
        mariadb = scaffolds,
        sqlite = {
          ["Insert row"] = 'INSERT INTO "{table}" (<columns>) VALUES (<values>);',
          ["Update rows"] = 'UPDATE "{table}" SET <col> = <value> WHERE <condition>;',
          ["Delete rows"] = 'DELETE FROM "{table}" WHERE <condition>;',
        },
      }

      local group = vim.api.nvim_create_augroup("DadbodPipeline", { clear = true })

      -- Source-patch lifecycle (see the build comment above): pristine before
      -- git operations, re-patched after — keeps upstream updates flowing.
      local dadbod_ui_dir = vim.fn.stdpath("data") .. "/lazy/vim-dadbod-ui"
      local function dadbod_ui_pristine()
        vim.system({ "git", "-C", dadbod_ui_dir, "checkout", "--", "autoload/" }):wait()
      end
      local function dadbod_ui_patch()
        vim.system({ "sh", "-c",
          "cd " .. vim.fn.shellescape(dadbod_ui_dir) ..
          [[ && sed -i 's/^\s*redraw!$/  " redraw! patched out: full-screen repaint blinks every pane/' autoload/db_ui/drawer.vim autoload/db_ui.vim]]
        }):wait()
      end
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = { "LazyUpdatePre", "LazyRestorePre", "LazySyncPre" },
        callback = dadbod_ui_pristine,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        -- post events; sed is a no-op when already patched, so this also
        -- covers "update fetched nothing" where build does not re-run
        pattern = { "LazyUpdate", "LazyRestore", "LazySync" },
        callback = dadbod_ui_patch,
      })

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
          -- Pane jumps like the terminal panes have: within the left column
          -- (tree above, slot below) and out to the editor.
          for key, dir in pairs({ ["<C-j>"] = "j", ["<C-k>"] = "k", ["<C-h>"] = "h", ["<C-l>"] = "l" }) do
            vim.keymap.set("n", key, "<Cmd>wincmd " .. dir .. "<CR>",
              { buffer = ev.buf, desc = "Window: " .. dir })
          end
          vim.keymap.set("n", "<leader>r", function()
            local label = vim.api.nvim_get_current_line():match("([%w%._%-]+)%s*$")
            local path
            if label then
              local base = vim.g.db_ui_save_location
              path = vim.fn.glob(base .. "/*/" .. label, false, true)[1]
                or vim.fn.glob(base .. "/*/" .. label .. ".sql", false, true)[1]
            end
            -- Helper lines (List/Columns/…): resolve template + table +
            -- connection from drawer text and the PUBLIC template API, then
            -- execute bufferless — zero focus changes (Neovide renders any
            -- cursor flight immediately, same-tick or not).
            if not path then
              local function label_of(text)
                local t = text:gsub("^%s*", "")
                -- drawer lines carry several glyph prefixes (expander + icon)
                while true do
                  local first, rest = t:match("^(%S+)%s+(.*)$")
                  if first and rest and not first:match("^[%w]") then t = rest else break end
                end
                return t
              end
              local function indent_of(text) return #(text:match("^%s*")) end
              local lnum = vim.api.nvim_win_get_cursor(0)[1]
              local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
              local helper_label = label_of(lines[lnum])
              local helper_indent = indent_of(lines[lnum])
              -- nearest ancestor with smaller indent = table; indent-1 chain up to connection
              local tbl, conn
              local cur_indent = helper_indent
              for i = lnum - 1, 1, -1 do
                local ind = indent_of(lines[i])
                if ind < cur_indent then
                  local lab = label_of(lines[i])
                  if not tbl then
                    tbl = lab
                  end
                  cur_indent = ind
                  if ind == 0 then conn = lab break end
                end
              end
              local url
              if conn then
                local function try(name, u)
                  if not url and vim.fn["db_ui#utils#slug"](name) == vim.fn["db_ui#utils#slug"](conn) then url = u end
                end
                local dbs = vim.g.dbs or {}
                if dbs[1] then
                  for _, d in ipairs(dbs) do try(d.name, d.url) end
                else
                  for n, u in pairs(dbs) do try(n, u) end
                end
                if not url then
                  local okj, conns = pcall(function()
                    return vim.json.decode(table.concat(
                      vim.fn.readfile(vim.g.db_ui_save_location .. "/connections.json"), "\n"))
                  end)
                  if okj then
                    for _, c in ipairs(conns or {}) do try(c.name, c.url) end
                  end
                end
              end
              local template
              if url and tbl and helper_label then
                local scheme = url:match("^([%w]+):")
                local okh, helpers = pcall(vim.fn["db_ui#table_helpers#get"], scheme)
                if okh and type(helpers) == "table" then template = helpers[helper_label] end
                -- scaffolds carry <placeholders>: open for editing, never run
                if template and template:find("<", 1, true) then
                  vim.cmd([[execute "normal \<Plug>(DBUI_SelectLine)"]])
                  return
                end
              end
              if template then
                local dbname = url:match("://[^/]+/([^?/]+)") or ""
                local sql = template
                  :gsub("{table}", tbl)
                  :gsub("{optional_schema}", "")
                  :gsub("{schema}", dbname)
                  :gsub("{dbname}", dbname)
                  :gsub("{last_query}", "")
                local dbtools = require("config.dbtools")
                dbtools.exec(url, sql)
                dbtools.set_last({ url = url, sql = sql, table = tbl })
                return
              end
            end

            if not path then
              -- Not a saved-query file or resolvable helper. Compose
              -- SelectLine + ExecuteQuery, then deterministically restore:
              -- the editor window gets its exact previous buffer back, or the
              -- transient split is closed if no editor existed before.
              local drawer_win = vim.api.nvim_get_current_win()
              local editor_win, editor_buf
              for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                local b = vim.api.nvim_win_get_buf(w)
                if vim.api.nvim_win_get_config(w).relative == "" and vim.bo[b].buftype == ""
                    and vim.bo[b].filetype ~= "dbui" then
                  editor_win, editor_buf = w, b
                  break
                end
              end
              vim.cmd([[execute "normal \<Plug>(DBUI_SelectLine)"]])
              local qwin = vim.api.nvim_get_current_win()
              local qbuf = vim.api.nvim_get_current_buf()
              local qft = vim.bo[qbuf].filetype
              if qwin == drawer_win or not (qft == "sql" or qft == "mysql" or qft == "plsql") then
                return -- plain toggle/expand: nothing opened
              end
              vim.cmd([[execute "normal \<Plug>(DBUI_ExecuteQuery)"]])
              -- Restore SAME-TICK: :DB captured the query text synchronously,
              -- and any repaint between swap-in and swap-back is the flicker.
              if editor_win and vim.api.nvim_win_is_valid(editor_win)
                  and editor_buf and vim.api.nvim_buf_is_valid(editor_buf) then
                pcall(vim.api.nvim_win_set_buf, editor_win, editor_buf)
              elseif not editor_win and vim.api.nvim_win_is_valid(qwin) then
                pcall(vim.api.nvim_win_close, qwin, false)
              end
              if vim.api.nvim_win_is_valid(drawer_win) then
                vim.api.nvim_set_current_win(drawer_win)
              end
              if vim.api.nvim_buf_is_valid(qbuf) then
                pcall(vim.api.nvim_buf_delete, qbuf, { force = true })
              end
              require("config.layout").sync()
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
            require("config.dbtools").confirm_exec(url,
              table.concat(vim.fn.readfile(path), "\n"))
          end, { buffer = ev.buf, desc = "DB: run query under cursor (no editor)" })
        end,
      })

      -- Query buffers: <leader>r runs the statement (normal: whole buffer /
      -- visual: selection) — mirrors the global "<leader>r runs current file".
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "sql", "mysql", "plsql" },
        callback = function(ev)
          local function guarded_execute(get_sql)
            return function()
              local dbtools = require("config.dbtools")
              local sql = get_sql()
              local danger = dbtools.dangerous(sql)
              if danger and vim.fn.confirm(
                    "Statement without WHERE:\n\n" .. danger .. "\n\nExecute anyway?",
                    "&Execute\n&Cancel", 2, "Warning") ~= 1 then
                vim.notify("DB: cancelled", vim.log.levels.INFO)
                return
              end
              -- record for result-row operations
              local key = vim.b[ev.buf].dbui_db_key_name
              local okc, conn = pcall(vim.fn["db_ui#get_conn_info"], key)
              dbtools.set_last({
                url = okc and conn.url or nil,
                sql = sql,
                table = dbtools.table_of(sql),
              })
              vim.cmd([[execute "normal \<Plug>(DBUI_ExecuteQuery)"]])
            end
          end
          vim.keymap.set("n", "<leader>r", guarded_execute(function()
            return table.concat(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false), "\n")
          end), { buffer = ev.buf, desc = "DB: execute query" })
          vim.keymap.set("v", "<leader>r", guarded_execute(function()
            local s0 = vim.fn.line("v")
            local e0 = vim.fn.line(".")
            if s0 > e0 then s0, e0 = e0, s0 end
            return table.concat(vim.api.nvim_buf_get_lines(ev.buf, s0 - 1, e0, false), "\n")
          end), { buffer = ev.buf, desc = "DB: execute selection" })
          -- :w executes too (db_ui_execute_on_save); guard that path as well
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = group,
            buffer = ev.buf,
            callback = function()
              local dbtools = require("config.dbtools")
              local sql = table.concat(vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false), "\n")
              local danger = dbtools.dangerous(sql)
              if danger and vim.fn.confirm(
                    "Statement without WHERE:\n\n" .. danger .. "\n\nExecute anyway?",
                    "&Execute\n&Cancel", 2, "Warning") ~= 1 then
                error("DB: write/execute cancelled")
              end
              local key = vim.b[ev.buf].dbui_db_key_name
              local okc, conn = pcall(vim.fn["db_ui#get_conn_info"], key)
              dbtools.set_last({
                url = okc and conn.url or nil,
                sql = sql,
                table = dbtools.table_of(sql),
              })
            end,
          })
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
          -- fzf row operations: enter = update a column, ctrl-x = delete row
          vim.keymap.set("n", "<leader>e", function()
            require("config.dbtools").row_menu()
          end, { buffer = ev.buf, desc = "DB: edit/delete result row" })
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
