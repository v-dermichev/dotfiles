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

local function install(package_id, version)
  resolve_csproj(function(proj)
    if not proj then return end
    local cmd = { "dotnet", "add", proj, "package", package_id }
    if version then vim.list_extend(cmd, { "--version", version }) end
    local pretty = package_id .. (version and ("@" .. version) or "")
    vim.notify("NuGet: adding " .. pretty .. " → " .. vim.fn.fnamemodify(proj, ":t") .. " …")
    vim.system(cmd, { text = true }, vim.schedule_wrap(function(out)
      if out.code == 0 then
        vim.notify("NuGet: installed " .. pretty, vim.log.levels.INFO)
      else
        vim.notify("NuGet: failed to add " .. pretty .. "\n" ..
          (out.stderr ~= "" and out.stderr or out.stdout), vim.log.levels.ERROR)
      end
    end))
  end)
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
      ["--header"] = "enter: install latest │ ctrl-v: pick version",
    },
    winopts = { preview = { horizontal = "right:55%" } },
    actions = {
      ["default"] = function(selected)
        local id = selected_id(selected)
        if id then install(id) end
      end,
      ["ctrl-v"] = function(selected)
        local id = selected_id(selected)
        if id then pick_version(id) end
      end,
    },
  })
end

-- exposed for headless testing only
M._test = { fetch = fetch, build_preview = build_preview, humanize = humanize }

return M
