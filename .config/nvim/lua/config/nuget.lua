-- Interactive NuGet package installer on top of fzf-lua.
-- <leader><leader>n → live search on the NuGet API; preview shows package
-- info + download counts; Enter installs the latest version into the nearest
-- .csproj (dotnet add package), Ctrl-V picks a specific version first.
local M = {}

local SEARCH_URL = "https://azuresearch-usnc.nuget.org/query"

-- jq helper: humanize download counts (8738738690 -> "8.7B")
local JQ_HUMANIZE =
  [[def h: if .>=1e9 then "\(./1e9*10|floor/10)B" elif .>=1e6 then "\(./1e6*10|floor/10)M" elif .>=1e3 then "\(./1e3*10|floor/10)K" else tostring end;]]

-- One search-result line: "<id>\t<version>\t<downloads>\t<verified>"
local function search_cmd(query)
  return string.format(
    [[curl -s --get %s --data-urlencode q=%s --data-urlencode take=40 --data-urlencode prerelease=false | jq -r '%s .data[] | [.id, .version, (.totalDownloads // 0 | h), (if .verified then "✓" else "·" end)] | @tsv']],
    SEARCH_URL, vim.fn.shellescape(query or ""), JQ_HUMANIZE)
end

-- fzf preview: {1} is the package id (fzf quotes placeholders safely).
local PREVIEW_CMD = [[sh -c '
id={1}
low=$(echo $id | tr "[:upper:]" "[:lower:]")
reg=$(curl -s --compressed https://api.nuget.org/v3/registration5-gz-semver2/$low/index.json)
pub=$(echo "$reg" | jq -r ".items[-1] | if .items then .items[-1].catalogEntry.published[0:10] else empty end" 2>/dev/null)
[ -z "$pub" ] && pub=$(curl -s --compressed "$(echo "$reg" | jq -r ".items[-1][\"@id\"]")" 2>/dev/null | jq -r ".items[-1].catalogEntry.published[0:10]" 2>/dev/null)
curl -s --get ]] .. SEARCH_URL .. [[ --data-urlencode "q=packageid:$id" | jq -r "]] ..
  [[def h: if .>=1e9 then \"\(./1e9*10|floor/10)B\" elif .>=1e6 then \"\(./1e6*10|floor/10)M\" elif .>=1e3 then \"\(./1e3*10|floor/10)K\" else tostring end;]] ..
  [[.data[0] | \"\(.id)  \(if .verified then \"✓ verified\" else \"\" end)\n\" +]] ..
  [[\"latest:    \(.version)\n\" +]] ..
  [[\"updated:   ${pub:--}\n\" +]] ..
  [[\"downloads: \(.totalDownloads // 0 | h)  (total)\n\" +]] ..
  [[\"owners:    \(.owners // [] | join(\", \"))\n\" +]] ..
  [[\"project:   \(.projectUrl // \"-\")\n\" +]] ..
  [[\"tags:      \(.tags // [] | join(\", \") | if . == \"\" then \"-\" else . end)\n\n\" +]] ..
  [[\"\(.description // \"\")\n\n\" +]] ..
  [[\"── recent versions ──\n\" +]] ..
  [[( [.versions[] | {v: .version, d: .downloads}] | reverse | .[0:12] | map(\"\(.v)  (\(.d // 0 | h))\") | join(\"\n\"))"
']]

-- Locate the target .csproj: nearest upward from the current file, else the
-- projects under cwd (vim.ui.select when there are several). Async: calls
-- on_done(path|nil).
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

local function pick_version(package_id)
  local fzf = require("fzf-lua")
  local cmd = string.format(
    [[curl -s --get %s --data-urlencode q=packageid:%s | jq -r '%s .data[0].versions | reverse | .[] | [.version, (.downloads // 0 | h)] | @tsv']],
    SEARCH_URL, vim.fn.shellescape(package_id), JQ_HUMANIZE)
  fzf.fzf_exec(cmd, {
    prompt = package_id .. " version> ",
    fzf_opts = { ["--delimiter"] = "\t", ["--header"] = "enter: install this version" },
    actions = {
      ["default"] = function(selected)
        local version = selected[1] and selected[1]:match("^([^\t]+)")
        if version then install(package_id, version) end
      end,
    },
  })
end

function M.pick()
  local fzf = require("fzf-lua")
  -- fzf-lua hands the live contents fn its args as a list: args[1] = query
  fzf.fzf_live(function(args)
    local query = type(args) == "table" and args[1] or args
    return search_cmd(query)
  end, {
    prompt = "NuGet> ",
    exec_empty_query = false,
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--nth"] = "1",
      ["--header"] = "enter: install latest │ ctrl-v: pick version",
      ["--preview"] = PREVIEW_CMD,
      ["--preview-window"] = "right:55%:wrap",
    },
    actions = {
      ["default"] = function(selected)
        local id = selected[1] and selected[1]:match("^([^\t]+)")
        if id then install(id) end
      end,
      ["ctrl-v"] = function(selected)
        local id = selected[1] and selected[1]:match("^([^\t]+)")
        if id then pick_version(id) end
      end,
    },
  })
end

return M
