-- DB workflow tools on top of vim-dadbod (used by plugins/dadbod.lua):
--   * exec/confirm_exec — bufferless %DB execution with a safety net:
--     UPDATE/DELETE statements without a WHERE clause require confirmation
--   * result-row operations — parse the dbout table under the cursor and
--     offer per-column UPDATE / row DELETE through an fzf-lua picker;
--     the WHERE is built from the full row identity
--
-- Row ops need to know which table/connection produced the results; every
-- execution path records that via set_last().
local M = {}

-- { url = ..., sql = ..., table = ... } of the last executed query
M.last = nil

function M.set_last(info)
  M.last = info
end

-- crude but effective: target table of a statement
function M.table_of(sql)
  local s = sql:lower()
  return (s:match("from%s+`?([%w_%.]+)`?")
    or s:match("update%s+`?([%w_%.]+)`?")
    or s:match("insert%s+into%s+`?([%w_%.]+)`?"))
end

-- first UPDATE/DELETE statement lacking a WHERE clause, or nil
function M.dangerous(sql)
  for stmt in (sql .. ";"):gmatch("([^;]+);") do
    local s = " " .. stmt:lower() .. " "
    if (s:find("%s+update%s") or s:find("^%s*update%s") or s:find("%s+delete%s") or s:find("^%s*delete%s"))
      and not s:find("%s+where%s") then
      local trimmed = vim.trim(stmt)
      if trimmed ~= "" then return trimmed end
    end
  end
  return nil
end

-- bufferless execution (scratch + %DB); never touches windows or focus
function M.exec(url, sql)
  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(sql, "\n"))
  vim.api.nvim_buf_call(scratch, function()
    vim.cmd("%DB " .. url)
  end)
  vim.schedule(function()
    pcall(vim.api.nvim_buf_delete, scratch, { force = true })
  end)
  M.set_last({ url = url, sql = sql, table = M.table_of(sql) })
  require("config.layout").sync()
end

-- exec with the no-WHERE guard
function M.confirm_exec(url, sql)
  local danger = M.dangerous(sql)
  if danger then
    local choice = vim.fn.confirm(
      "Statement without WHERE:\n\n" .. danger .. "\n\nExecute anyway?",
      "&Execute\n&Cancel", 2, "Warning")
    if choice ~= 1 then
      vim.notify("DB: cancelled", vim.log.levels.INFO)
      return false
    end
  end
  M.exec(url, sql)
  return true
end

-- ---------------------------------------------------------------------------
-- dbout parsing (two client formats)
-- ---------------------------------------------------------------------------

-- mysql/mariadb -t:  | id | name |        sqlite -column:  id  name
--                    +----+------+                         --  ----
local function parse_pipe_row(header, line)
  local function cells(l)
    local out = {}
    for cell in l:gmatch("|([^|]*)") do
      table.insert(out, vim.trim(cell))
    end
    -- trailing split artifact from the final pipe
    if #out > 0 and out[#out] == "" then table.remove(out) end
    return out
  end
  local cols, vals = cells(header), cells(line)
  if #cols == 0 or #cols ~= #vals then return nil end
  return cols, vals
end

local function parse_column_row(header, dashes, line)
  -- column ranges from the dashes line ("--  -----")
  local cols, vals = {}, {}
  local start = 1
  while true do
    local s, e = dashes:find("%-+", start)
    if not s then break end
    table.insert(cols, vim.trim(header:sub(s, e)))
    table.insert(vals, vim.trim(line:sub(s, e)))
    start = e + 1
  end
  if #cols == 0 then return nil end
  return cols, vals
end

-- parse the result row under the cursor: returns { cols, vals } or nil
function M.row_under_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local line = lines[lnum]
  if not line or line == "" then return nil end

  if line:match("^%s*|") then -- pipe format; header = first pipe line
    for i = 1, lnum - 1 do
      if lines[i]:match("^%s*|") then
        if i == lnum then return nil end
        local cols, vals = parse_pipe_row(lines[i], line)
        if cols and lnum > i + 1 then return cols, vals end -- skip header itself
        return nil
      end
    end
    return nil
  end

  -- column format: dashes on line 2, header on line 1
  if lines[2] and lines[2]:match("^%-[%- ]*$") and lnum > 2 then
    return parse_column_row(lines[1], lines[2], line)
  end
  return nil
end

-- every data row of the result buffer: { cols = {...}, rows = { {display, vals}, ... } }
function M.all_rows(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
  if not lines[1] then return nil end

  local cols, rows = nil, {}
  if lines[1]:match("^%s*[+|]") then -- mariadb/mysql -t
    local header
    for _, l in ipairs(lines) do
      if l:match("^%s*|") then
        if not header then
          header = l
          cols = select(1, parse_pipe_row(l, l))
        else
          local c, v = parse_pipe_row(header, l)
          if c then table.insert(rows, { display = l, vals = v }) end
        end
      end
    end
  elseif lines[2] and lines[2]:match("^%-[%- ]*$") then -- sqlite column mode
    for i = 3, #lines do
      if lines[i] ~= "" then
        local c, v = parse_column_row(lines[1], lines[2], lines[i])
        if c then
          cols = cols or c
          table.insert(rows, { display = lines[i], vals = v })
        end
      end
    end
  end
  if not cols or #rows == 0 then return nil end
  return cols, rows
end

-- ---------------------------------------------------------------------------
-- row operations (fzf-lua)
-- ---------------------------------------------------------------------------

local function sql_value(v)
  if v == "NULL" or v == "" then return nil end
  if v:match("^%-?%d+%.?%d*$") then return v end -- numeric literal (sqlite is typed)
  return "'" .. v:gsub("'", "''") .. "'"
end

local function identity_where(cols, vals)
  local parts = {}
  for i, c in ipairs(cols) do
    local v = sql_value(vals[i])
    if v == nil then
      table.insert(parts, "`" .. c .. "` IS NULL")
    else
      table.insert(parts, "`" .. c .. "` = " .. v)
    end
  end
  return table.concat(parts, " AND ")
end

-- Build INSERT from collected values; columns with nil are omitted so
-- database defaults / auto-increment apply. vals_map[col] == vim.NIL means
-- an explicit NULL.
function M.build_insert(tbl, cols, vals_map)
  local names, values = {}, {}
  for _, c in ipairs(cols) do
    local v = vals_map[c]
    if v ~= nil then
      table.insert(names, "`" .. c .. "`")
      if v == vim.NIL then
        table.insert(values, "NULL")
      else
        table.insert(values, sql_value(v) or "NULL")
      end
    end
  end
  if #names == 0 then return nil end
  return ("INSERT INTO `%s` (%s) VALUES (%s);"):format(
    tbl, table.concat(names, ", "), table.concat(values, ", "))
end

-- Sequentially prompt for each column (prefilled with the source row's
-- values — clone-and-tweak); empty input skips the column, the literal
-- string NULL inserts NULL.
local function insert_flow(url, tbl, cols, vals)
  local collected = {}
  local i = 0
  local function step()
    i = i + 1
    if not cols[i] then
      local sql = M.build_insert(tbl, cols, collected)
      if not sql then
        return vim.notify("DB: all columns skipped — nothing to insert", vim.log.levels.WARN)
      end
      if vim.fn.confirm(sql, "&Execute\n&Cancel", 1) == 1 then
        M.exec(url, sql)
      end
      return
    end
    vim.ui.input({
      prompt = ("`%s` (%d/%d, empty = skip) = "):format(cols[i], i, #cols),
      default = vals[i] ~= "NULL" and vals[i] or "",
    }, function(input)
      if input == nil then return end -- aborted: cancel whole flow
      if input ~= "" then
        collected[cols[i]] = input == "NULL" and vim.NIL or input
      end
      step()
    end)
  end
  step()
end

-- <leader>e in dbout: fzf over the RESULT ROWS (multi-select with tab).
-- enter = update one column across the selected rows, ctrl-x = delete the
-- selected rows, ctrl-a = insert (clone of the first selected row).
function M.row_menu()
  local cols, rows = M.all_rows(0)
  if not cols then
    return vim.notify("DB: no parseable result rows in this buffer", vim.log.levels.WARN)
  end
  local last = M.last or {}
  local url, tbl = last.url, last.table
  if not url then
    return vim.notify("DB: no tracked connection for these results", vim.log.levels.WARN)
  end
  if not tbl then
    tbl = vim.fn.input("Table name: ")
    if tbl == "" then return end
  end
  local is_mysql = url:match("^mysql") or url:match("^mariadb")
  local limit = is_mysql and " LIMIT 1" or ""

  -- display line -> parsed vals (identical rows share identity anyway)
  local by_display = {}
  local entries = {}
  for _, r in ipairs(rows) do
    by_display[vim.trim(r.display)] = r.vals
    table.insert(entries, r.display)
  end
  local function selected_rows(selected)
    local out = {}
    for _, line in ipairs(selected or {}) do
      local v = by_display[vim.trim(line)]
      if v then table.insert(out, v) end
    end
    return out
  end

  require("fzf-lua").fzf_exec(entries, {
    prompt = tbl .. " rows> ",
    fzf_opts = {
      ["--multi"] = true,
      ["--header"] = table.concat(cols, " │ ")
        .. "  ▏tab: mark │ enter: update column │ ctrl-x: delete │ ctrl-a: insert clone",
    },
    actions = {
      ["default"] = function(selected)
        local picked = selected_rows(selected)
        if #picked == 0 then return end
        -- second stage: which column to set (values of the first picked row shown)
        local col_entries = {}
        for i, c in ipairs(cols) do
          table.insert(col_entries, ("%s\t%s"):format(c, picked[1][i]))
        end
        require("fzf-lua").fzf_exec(col_entries, {
          prompt = tbl .. " set> ",
          fzf_opts = { ["--delimiter"] = "\t", ["--header"] = "column to update for " .. #picked .. " row(s)" },
          actions = {
            ["default"] = function(csel)
              local col = csel[1] and csel[1]:match("^([^\t]+)")
              if not col then return end
              local ci
              for i, c in ipairs(cols) do
                if c == col then ci = i end
              end
              vim.ui.input({ prompt = "SET `" .. col .. "` = ", default = picked[1][ci] },
                function(newval)
                  if newval == nil then return end
                  local v = newval == "NULL" and "NULL" or (sql_value(newval) or "NULL")
                  local stmts = {}
                  for _, vals in ipairs(picked) do
                    table.insert(stmts, ("UPDATE `%s` SET `%s` = %s WHERE %s%s;")
                      :format(tbl, col, v, identity_where(cols, vals), limit))
                  end
                  local sql = table.concat(stmts, "\n")
                  if vim.fn.confirm(sql, "&Execute\n&Cancel", 1) == 1 then
                    M.exec(url, sql)
                  end
                end)
            end,
          },
        })
      end,
      ["ctrl-x"] = function(selected)
        local picked = selected_rows(selected)
        if #picked == 0 then return end
        local stmts = {}
        for _, vals in ipairs(picked) do
          table.insert(stmts, ("DELETE FROM `%s` WHERE %s%s;")
            :format(tbl, identity_where(cols, vals), limit))
        end
        local sql = table.concat(stmts, "\n")
        if vim.fn.confirm(sql, "&Execute\n&Cancel", 2, "Warning") == 1 then
          M.exec(url, sql)
        end
      end,
      ["ctrl-a"] = function(selected)
        local picked = selected_rows(selected)
        if #picked == 0 then return end
        insert_flow(url, tbl, cols, picked[1])
      end,
    },
  })
end

return M
