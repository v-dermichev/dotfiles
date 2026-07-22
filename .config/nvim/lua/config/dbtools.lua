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

-- <leader>e in dbout: fzf over the row's columns.
-- enter = update that column, ctrl-x = delete the row.
function M.row_menu()
  local cols, vals = M.row_under_cursor()
  if not cols then
    return vim.notify("DB: no result row under cursor", vim.log.levels.WARN)
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
  -- sqlite quoting: backticks are mysql-ish; sqlite accepts them too, but
  -- DELETE ... LIMIT is mysql-only
  local is_mysql = url:match("^mysql") or url:match("^mariadb")
  local where = identity_where(cols, vals)
  local limit = is_mysql and " LIMIT 1" or ""

  local entries = {}
  for i, c in ipairs(cols) do
    table.insert(entries, ("%s\t%s"):format(c, vals[i]))
  end
  require("fzf-lua").fzf_exec(entries, {
    prompt = tbl .. " row> ",
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--header"] = "enter: update column │ ctrl-x: delete row",
    },
    actions = {
      ["default"] = function(selected)
        local col = selected[1] and selected[1]:match("^([^\t]+)")
        if not col then return end
        local current
        for i, c in ipairs(cols) do
          if c == col then current = vals[i] end
        end
        vim.ui.input({ prompt = "SET `" .. col .. "` = ", default = current }, function(newval)
          if newval == nil then return end
          local v = sql_value(newval) or "NULL"
          local sql = ("UPDATE `%s` SET `%s` = %s WHERE %s%s;"):format(tbl, col, v, where, limit)
          if vim.fn.confirm(sql, "&Execute\n&Cancel", 1) == 1 then
            M.exec(url, sql)
          end
        end)
      end,
      ["ctrl-x"] = function()
        local sql = ("DELETE FROM `%s` WHERE %s%s;"):format(tbl, where, limit)
        if vim.fn.confirm(sql, "&Execute\n&Cancel", 2, "Warning") == 1 then
          M.exec(url, sql)
        end
      end,
    },
  })
end

return M
