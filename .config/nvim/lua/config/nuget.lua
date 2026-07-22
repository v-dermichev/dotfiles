-- Interactive NuGet package installer on top of fzf-lua.
-- <leader><leader>n → live search on the NuGet API; preview shows package
-- info, release date and download counts; Enter installs the latest version
-- into the nearest .csproj (dotnet add package), Ctrl-V picks a version.
-- All API plumbing lives in scripts/nuget.sh (search|preview|versions).
local M = {}

local SCRIPT = vim.fn.stdpath("config") .. "/scripts/nuget.sh"

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

local function selected_id(selected)
  return selected[1] and selected[1]:match("^([^\t]+)")
end

local function pick_version(package_id)
  require("fzf-lua").fzf_exec(
    SCRIPT .. " versions " .. vim.fn.shellescape(package_id), {
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
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--nth"] = "1",
      ["--header"] = "enter: install latest │ ctrl-v: pick version",
      ["--preview"] = SCRIPT .. " preview {1}",
      ["--preview-window"] = "right:55%:wrap",
    },
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

return M
