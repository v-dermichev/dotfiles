-- Interactive NuGet package installer on top of fzf-lua.
-- <leader><leader>n → live search on the NuGet API; preview shows package
-- info, release date and download counts; Enter installs the latest version
-- into the nearest .csproj (dotnet add package), Ctrl-V picks a version.
--
-- The live search line-feed stays a tiny shell command (scripts/nuget.sh) —
-- fzf's live contents must be a spawnable command. Everything else runs
-- in-process: the preview is a lua previewer rendering into a buffer, backed
-- by a memory + disk cache with ETag revalidation (a 304 keeps the cache;
-- only real metadata changes refetch). Stale data is served on network error.
local M = {}

local SCRIPT = vim.fn.stdpath("config") .. "/scripts/nuget.sh"
local API = "https://azuresearch-usnc.nuget.org/query"
local FLAT = "https://api.nuget.org/v3-flatcontainer"
local REG = "https://api.nuget.org/v3/registration5-gz-semver2"
local TTL = tonumber(vim.env.NUGET_CACHE_TTL) or 600

-- ---------------------------------------------------------------------------
-- fetch layer: JSON GET with memory + disk cache and ETag revalidation
-- ---------------------------------------------------------------------------
local cache_dir = vim.fn.stdpath("cache") .. "/nuget"
local mem = {}     -- url -> { time, etag, body }
local pending = {} -- url -> { cb, ... } (dedupe concurrent fetches)

local function disk_path(url)
  return cache_dir .. "/" .. vim.fn.sha256(url):sub(1, 32) .. ".json"
end

local function disk_write(url, entry)
  vim.fn.mkdir(cache_dir, "p")
  local ok, encoded = pcall(vim.json.encode, entry)
  if ok then pcall(vim.fn.writefile, { encoded }, disk_path(url)) end
end

local function disk_read(url)
  local ok, entry = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(disk_path(url)), "\n"))
  end)
  return ok and type(entry) == "table" and entry.body ~= nil and entry or nil
end

-- fetch(url, cb): cb(body|nil) on the main loop. Fresh cache answers
-- immediately; stale cache revalidates via If-None-Match.
local function fetch(url, cb)
  local now = os.time()
  local entry = mem[url]
  if not entry then
    entry = disk_read(url)
    if entry then mem[url] = entry end
  end
  if entry and now - (entry.time or 0) < TTL then return cb(entry.body) end

  if pending[url] then
    table.insert(pending[url], cb)
    return
  end
  pending[url] = { cb }

  local hdrfile = vim.fn.tempname()
  local args = { "curl", "-s", "--compressed", "--max-time", "10", "-D", hdrfile, url }
  if entry and entry.etag then
    vim.list_extend(args, { "-H", "If-None-Match: " .. entry.etag })
  end
  vim.system(args, { text = true }, vim.schedule_wrap(function(out)
    local cbs = pending[url] or {}
    pending[url] = nil

    local status, etag
    local okh, hdrs = pcall(vim.fn.readfile, hdrfile)
    if okh then
      for _, l in ipairs(hdrs) do
        local s = l:match("^HTTP/[%d.]+%s+(%d+)")
        if s then status = tonumber(s) end
        local e = l:match("^[Ee][Tt]ag:%s*(.-)%s*$")
        if e then etag = e end
      end
    end
    pcall(vim.fn.delete, hdrfile)

    local body
    if out.code == 0 and status == 304 and entry then
      entry.time = os.time()
      disk_write(url, entry)
      body = entry.body
    elseif out.code == 0 and status and status < 400 and out.stdout and out.stdout ~= "" then
      local okj, decoded = pcall(vim.json.decode, out.stdout)
      if okj then
        body = decoded
        mem[url] = { time = os.time(), etag = etag, body = decoded }
        disk_write(url, mem[url])
      end
    end
    if body == nil and entry then body = entry.body end -- stale on error

    for _, f in ipairs(cbs) do f(body) end
  end))
end

-- ---------------------------------------------------------------------------
-- rendering helpers
-- ---------------------------------------------------------------------------
local function humanize(n)
  n = tonumber(n) or 0
  if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
  if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
  return tostring(n)
end

local function urlencode(s)
  return (s:gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- newest LISTED release date from a registration index (unlisted versions
-- carry published=1900-01-01); pages either inline items or point to a page
local function published_date(id, cb)
  fetch(REG .. "/" .. id:lower() .. "/index.json", function(reg)
    local pages = reg and reg.items
    local last = pages and pages[#pages]
    local function max_published(items)
      local best
      for _, it in ipairs(items or {}) do
        local p = it.catalogEntry and it.catalogEntry.published
        if p and p:sub(1, 4) ~= "1900" and (not best or p > best) then best = p end
      end
      return best and best:sub(1, 10) or nil
    end
    if last and last.items then return cb(max_published(last.items)) end
    if last and last["@id"] then
      return fetch(last["@id"], function(page)
        cb(page and max_published(page.items) or nil)
      end)
    end
    cb(nil)
  end)
end

-- build_preview(id, cb): cb(lines) — assembled package info card
local function build_preview(id, cb)
  published_date(id, function(pub)
    fetch(API .. "?q=packageid:" .. urlencode(id), function(info)
      local d = info and info.data and info.data[1]
      if d then
        local lines = {
          d.id .. (d.verified and "  ✓ verified" or ""),
          "latest:    " .. (d.version or "-"),
          "updated:   " .. (pub or "-"),
          "downloads: " .. humanize(d.totalDownloads) .. "  (total)",
          "owners:    " .. table.concat(d.owners or {}, ", "),
          "project:   " .. (d.projectUrl or "-"),
          "tags:      " .. (#(d.tags or {}) > 0 and table.concat(d.tags, ", ") or "-"),
          "",
        }
        for _, l in ipairs(vim.split(d.description or "", "\n")) do
          table.insert(lines, l)
        end
        vim.list_extend(lines, { "", "── recent versions ──" })
        local versions = d.versions or {}
        for i = #versions, math.max(1, #versions - 11), -1 do
          local v = versions[i]
          table.insert(lines, ("%s  (%s)"):format(v.version, humanize(v.downloads)))
        end
        return cb(lines)
      end
      -- not in the search index (e.g. MySql.EntityFrameworkCore)
      fetch(FLAT .. "/" .. id:lower() .. "/index.json", function(flat)
        local lines = {
          id .. "  (absent from the NuGet search index)",
          "updated:   " .. (pub or "-"),
          "",
          "── versions ──",
        }
        local vs = flat and flat.versions or {}
        for i = #vs, math.max(1, #vs - 11), -1 do
          table.insert(lines, vs[i])
        end
        cb(lines)
      end)
    end)
  end)
end

-- ---------------------------------------------------------------------------
-- fzf-lua previewer (in-process; no subprocess per cursor move)
-- ---------------------------------------------------------------------------
local function make_previewer()
  local builtin = require("fzf-lua.previewer.builtin")
  local P = builtin.base:extend()

  function P:new(o, opts, fzf_win)
    P.super.new(self, o, opts, fzf_win)
    -- fzf-lua deep-extends opts, which strips this table's metatable; restore
    -- it so the base class methods (get_tmp_buffer & co) resolve again.
    setmetatable(self, P)
    return self
  end

  function P:gen_winopts()
    return vim.tbl_extend("force", self.winopts, { wrap = true, number = false, cursorline = false })
  end

  function P:populate_preview_buf(entry_str)
    local id = entry_str and entry_str:match("^([^\t]+)")
    if not id then return end
    self._wanted = id
    build_preview(id, function(lines)
      -- stale callback (cursor moved on) or preview window gone
      if self._wanted ~= id then return end
      if not self.win or not self.win:validate_preview() then return end
      local buf = self:get_tmp_buffer()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      self:set_preview_buf(buf)
      self.win:update_preview_title(" " .. id .. " ")
    end)
  end

  return P
end

-- ---------------------------------------------------------------------------
-- project resolution + install
-- ---------------------------------------------------------------------------
local function resolve_csproj(on_done)
  local file = vim.api.nvim_buf_get_name(0)
  local dir = file ~= "" and vim.fs.dirname(file) or vim.uv.cwd()
  local proj = vim.fs.find(function(n) return n:match("%.csproj$") end,
    { upward = true, path = dir, type = "file" })[1]
  if proj then return on_done(proj) end

  local all = vim.fn.glob(vim.uv.cwd() .. "/**/*.csproj", false, true)
  if #all == 0 then
    vim.notify("NuGet: no .csproj found", vim.log.levels.ERROR)
    return on_done(nil)
  end
  if #all == 1 then return on_done(all[1]) end
  vim.ui.select(all, { prompt = "Add package to project:" }, on_done)
end

-- dotnet add/remove rewrite the csproj on disk; if it's open in a buffer,
-- pick the change up (checktime reloads unmodified buffers via autoread).
local function refresh_csproj_buf(proj)
  local want = vim.fn.fnamemodify(proj, ":p")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf)
        and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p") == want then
      vim.api.nvim_buf_call(buf, function() vim.cmd("checktime") end)
    end
  end
end

-- ---------------------------------------------------------------------------
-- statusline reporting (consumed by lualine via M.statusline())
-- ---------------------------------------------------------------------------
local status_text = nil
local status_gen = 0 -- invalidates delayed clears when a new op starts

local function set_status(txt, clear_after_ms)
  status_text = txt
  status_gen = status_gen + 1
  local gen = status_gen
  vim.schedule(function() pcall(vim.cmd.redrawstatus) end)
  if clear_after_ms then
    vim.defer_fn(function()
      if status_gen == gen then
        status_text = nil
        pcall(vim.cmd.redrawstatus)
      end
    end, clear_after_ms)
  end
end

function M.statusline()
  return status_text or ""
end

-- run a dotnet package operation against proj (resolved when nil);
-- on_done() fires after completion either way (used to sequence batches);
-- progress ("2/5") prefixes the statusline text for batches
local function dotnet_op(op, package_id, version, proj, on_done, progress)
  local function run(p)
    if not p then
      if on_done then on_done() end
      return
    end
    local cmd = { "dotnet", op, p, "package", package_id }
    if version then vim.list_extend(cmd, { "--version", version }) end
    local pretty = package_id .. (version and ("@" .. version) or "")
    local verb = op == "remove" and "removing" or "adding"
    local prefix = progress and ("[" .. progress .. "] ") or ""
    set_status(("󰏗 %s%s %s → %s"):format(prefix, verb, pretty, vim.fn.fnamemodify(p, ":t")))
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(out)
      if out.code == 0 then
        set_status(("✓ %s%s %s"):format(prefix, op == "remove" and "removed" or "installed", pretty), 4000)
        refresh_csproj_buf(p)
      else
        set_status("✗ dotnet " .. op .. " failed: " .. pretty, 6000)
        vim.notify("NuGet: dotnet " .. op .. " failed for " .. pretty .. "\n" ..
          (out.stderr ~= "" and out.stderr or out.stdout), vim.log.levels.ERROR)
      end
      if on_done then on_done() end
    end))
  end
  if proj then run(proj) else resolve_csproj(run) end
end

-- ids from every selected row (fzf --multi hands all marked entries)
local function selected_ids(selected)
  local ids = {}
  for _, line in ipairs(selected or {}) do
    local id = line:match("^([^\t]+)")
    if id then table.insert(ids, id) end
  end
  return ids
end

-- run one dotnet op per id, strictly sequentially — concurrent dotnet
-- add/remove runs against the same csproj race on the file rewrite
local function batch_op(op, ids, proj)
  local i = 0
  local function step()
    i = i + 1
    if not ids[i] then return end
    local progress = #ids > 1 and (i .. "/" .. #ids) or nil
    dotnet_op(op, ids[i], nil, proj, step, progress)
  end
  -- resolve the project once for the whole batch
  if proj or #ids == 0 then
    step()
  else
    resolve_csproj(function(p)
      if not p then return end
      proj = p
      step()
    end)
  end
end

local function install(package_id, version, proj)
  dotnet_op("add", package_id, version, proj)
end

-- PackageReference entries of a csproj: { { id = ..., version = ... }, ... }
-- (attribute order tolerant; child-element <Version> not handled — rare)
local function installed_packages(proj)
  local ok, file_lines = pcall(vim.fn.readfile, proj)
  if not ok then return {} end
  local pkgs = {}
  for _, l in ipairs(file_lines) do
    local tag = l:match("<PackageReference%s+([^/>]+)")
    if tag then
      local id = tag:match('Include="([^"]+)"')
      local version = tag:match('Version="([^"]+)"')
      if id then table.insert(pkgs, { id = id, version = version or "?" }) end
    end
  end
  return pkgs
end

local function selected_id(selected)
  return selected and selected[1] and selected[1]:match("^([^\t]+)")
end

-- ---------------------------------------------------------------------------
-- pickers
-- ---------------------------------------------------------------------------
local function pick_version(package_id)
  require("fzf-lua").fzf_exec(function(fzf_cb)
    fetch(API .. "?q=packageid:" .. urlencode(package_id), function(info)
      local d = info and info.data and info.data[1]
      if d and d.versions and #d.versions > 0 then
        for i = #d.versions, 1, -1 do
          local v = d.versions[i]
          fzf_cb(("%s\t%s"):format(v.version, humanize(v.downloads)))
        end
        return fzf_cb()
      end
      -- search-index-absent fallback
      fetch(FLAT .. "/" .. package_id:lower() .. "/index.json", function(flat)
        local vs = flat and flat.versions or {}
        for i = #vs, 1, -1 do
          fzf_cb(vs[i] .. "\t-")
        end
        fzf_cb()
      end)
    end)
  end, {
    prompt = package_id .. " version> ",
    fzf_opts = { ["--delimiter"] = "\t", ["--header"] = "enter: install this version" },
    actions = {
      ["default"] = function(selected)
        local version = selected_id(selected)
        if version then install(package_id, version) end
      end,
    },
  })
end

-- <leader>pr — remove an installed package (previewed like the add picker)
function M.remove()
  resolve_csproj(function(proj)
    if not proj then return end
    local pkgs = installed_packages(proj)
    if #pkgs == 0 then
      return vim.notify("NuGet: no PackageReference entries in " ..
        vim.fn.fnamemodify(proj, ":t"), vim.log.levels.WARN)
    end
    local lines = {}
    for _, p in ipairs(pkgs) do
      table.insert(lines, ("%s\t%s"):format(p.id, p.version))
    end
    require("fzf-lua").fzf_exec(lines, {
      prompt = "NuGet remove> ",
      previewer = make_previewer(),
      fzf_opts = {
        ["--delimiter"] = "\t",
        ["--nth"] = "1",
        ["--multi"] = true,
        ["--header"] = vim.fn.fnamemodify(proj, ":t") .. " │ tab: mark │ enter: remove",
      },
      winopts = { preview = { horizontal = "right:55%" } },
      actions = {
        ["default"] = function(selected)
          batch_op("remove", selected_ids(selected), proj)
        end,
      },
    })
  end)
end

-- <leader>pu — update an installed package to the latest stable
function M.update()
  resolve_csproj(function(proj)
    if not proj then return end
    local pkgs = installed_packages(proj)
    if #pkgs == 0 then
      return vim.notify("NuGet: no PackageReference entries in " ..
        vim.fn.fnamemodify(proj, ":t"), vim.log.levels.WARN)
    end
    require("fzf-lua").fzf_exec(function(fzf_cb)
      -- collect all rows first so outdated packages sort above up-to-date ones
      local rows, remaining = {}, #pkgs
      for _, p in ipairs(pkgs) do
        fetch(FLAT .. "/" .. p.id:lower() .. "/index.json", function(flat)
          local latest
          for _, v in ipairs(flat and flat.versions or {}) do
            if not v:find("-", 1, true) then latest = v end
          end
          local outdated = latest ~= nil and latest ~= p.version
          table.insert(rows, {
            outdated = outdated,
            line = ("%s\t%s\t%s"):format(p.id, p.version,
              outdated and "↑ " .. latest or "up-to-date"),
          })
          remaining = remaining - 1
          if remaining == 0 then
            table.sort(rows, function(a, b)
              if a.outdated ~= b.outdated then return a.outdated end
              return a.line < b.line
            end)
            for _, r in ipairs(rows) do fzf_cb(r.line) end
            fzf_cb()
          end
        end)
      end
    end, {
      prompt = "NuGet update> ",
      previewer = make_previewer(),
      fzf_opts = {
        ["--delimiter"] = "\t",
        ["--nth"] = "1",
        ["--multi"] = true,
        ["--header"] = vim.fn.fnamemodify(proj, ":t") .. " │ tab: mark │ enter: update to latest",
      },
      winopts = { preview = { horizontal = "right:55%" } },
      actions = {
        ["default"] = function(selected)
          batch_op("add", selected_ids(selected), proj)
        end,
      },
    })
  end)
end

-- <leader>pa — search & add a package
function M.pick()
  -- fzf-lua hands the live contents fn its args as a list: args[1] = query
  require("fzf-lua").fzf_live(function(args)
    local query = type(args) == "table" and args[1] or args
    return SCRIPT .. " search " .. vim.fn.shellescape(query or "")
  end, {
    prompt = "NuGet> ",
    exec_empty_query = false,
    previewer = make_previewer(),
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--nth"] = "1",
      ["--multi"] = true,
      ["--header"] = "tab: mark │ enter: install latest │ ctrl-v: pick version",
    },
    winopts = { preview = { horizontal = "right:55%" } },
    actions = {
      ["default"] = function(selected)
        batch_op("add", selected_ids(selected), nil)
      end,
      ["ctrl-v"] = function(selected)
        local id = selected_id(selected)
        if id then pick_version(id) end
      end,
    },
  })
end

-- exposed for headless testing only
M._test = {
  fetch = fetch,
  build_preview = build_preview,
  humanize = humanize,
  installed_packages = installed_packages,
}

return M
