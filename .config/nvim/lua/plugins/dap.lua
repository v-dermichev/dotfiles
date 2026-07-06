-- Debugging: nvim-dap core + UI + virtual text, with Python (debugpy)
-- wired up. debugpy is installed via mason-nvim-dap; the program under
-- test runs with the active venv's python (see lua/config/venv.lua).
return {
  "mfussenegger/nvim-dap",
  dependencies = {
    "rcarriga/nvim-dap-ui",
    "nvim-neotest/nvim-nio",
    "theHamsta/nvim-dap-virtual-text",
    "jay-babu/mason-nvim-dap.nvim",
    "mfussenegger/nvim-dap-python",
  },
  keys = {
    { "<leader>db",  function() require("dap").toggle_breakpoint() end,                            desc = "DAP: toggle breakpoint" },
    { "<leader>dB",  function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end,     desc = "DAP: conditional breakpoint" },
    { "<leader>dh",  function() require("dap").set_breakpoint(nil, vim.fn.input("Hit count: "), nil) end, desc = "DAP: hit-count breakpoint" },
    { "<leader>dX",  function() require("dap").clear_breakpoints() end,                             desc = "DAP: clear all breakpoints" },
    { "<leader>dx",  function()
        -- Break on exceptions, picking from the adapter's advertised filters
        -- (clreval offers "all" / "user-unhandled"; exceptionInfo fills the stop).
        local dap = require("dap")
        local s = dap.session()
        local filters = s and s.capabilities and s.capabilities.exceptionBreakpointFilters
        if filters and #filters > 0 then
          local labels = vim.tbl_map(function(f) return f.label or f.filter end, filters)
          vim.ui.select(labels, { prompt = "Break on exceptions:" }, function(_, idx)
            if idx then dap.set_exception_breakpoints({ filters[idx].filter }) end
          end)
        else
          dap.set_exception_breakpoints({ "user-unhandled" })
        end
      end, desc = "DAP: break on exceptions (pick filter)" },
    { "<leader>dc",  function() require("dap").continue() end,                                      desc = "DAP: continue" },
    { "<leader>dP",  function() require("dap").pause() end,                                         desc = "DAP: pause running program" },
    { "<F5>",        function() require("dap").continue() end,                                      desc = "DAP: continue" },
    { "<leader>dd",  function()
        local file = vim.fn.expand("%:p")
        vim.cmd("w") -- save current file
        if vim.bo.filetype ~= "python" then
          -- Non-Python: fall back to picking a configured launch config.
          require("dap").continue()
          return
        end
        -- Launch the current file under debugpy as a module from the project
        -- root (module + cwd/PYTHONPATH) so intra-package imports resolve —
        -- same reasoning as <leader>r. Falls back to launching by path when the
        -- location can't form a valid dotted module name.
        local marker = vim.fs.find(
          { "pyproject.toml", "setup.py", "setup.cfg", ".git", ".venv" },
          { path = vim.fs.dirname(file), upward = true }
        )[1]
        local root = marker and vim.fs.dirname(marker) or vim.fs.dirname(file)
        local module = file:sub(#root + 2):gsub("%.py$", ""):gsub("[/\\]", ".")
        local runnable_module = #module > 0
        for seg in module:gmatch("[^.]+") do
          if not seg:match("^[%a_][%w_]*$") then runnable_module = false end
        end
        local config = {
          type = "python",
          request = "launch",
          name = "Debug current file",
          cwd = root,
          env = { PYTHONPATH = root },
          console = "integratedTerminal",
          justMyCode = false,
        }
        if runnable_module then config.module = module else config.program = file end
        require("dap").run(config)
      end, desc = "DAP: debug current file" },
    { "<leader>di",  function() require("dap").step_into() end,                                     desc = "DAP: step into" },
    { "<F11>",       function() require("dap").step_into() end,                                     desc = "DAP: step into" },
    { "<leader>do",  function() require("dap").step_over() end,                                     desc = "DAP: step over" },
    { "<F10>",       function() require("dap").step_over() end,                                     desc = "DAP: step over" },
    { "<leader>dO",  function() require("dap").step_out() end,                                      desc = "DAP: step out" },
    { "<leader>dR",  function() require("dap").run_to_cursor() end,                                 desc = "DAP: run to cursor" },
    { "<leader>dk",  function() require("dap").up() end,                                            desc = "DAP: stack frame up (caller)" },
    { "<leader>dj",  function() require("dap").down() end,                                          desc = "DAP: stack frame down (callee)" },
    { "<leader>dr",  function() require("dap").repl.toggle() end,                                   desc = "DAP: toggle REPL" },
    { "<leader>dl",  function() require("dap").run_last() end,                                      desc = "DAP: run last" },
    { "<leader>dt",  function() require("dap").terminate() end,                                     desc = "DAP: terminate (kill debuggee)" },
    { "<leader>dD",  function() require("dap").disconnect({ terminateDebuggee = false }) end,       desc = "DAP: detach (leave debuggee running)" },
    { "<leader>du",  function() require("config.term_tabs").show_ext("dap_scopes") end,              desc = "DAP: scopes pane" },
    { "<leader>de",  function() require("dapui").eval() end, mode = { "n", "v" },                   desc = "DAP: eval (under cursor)" },
    { "<leader>dE",  function()
        require("config.term_tabs").show_ext("dap_eval")
        require("config.dap_eval").focus_insert()
      end, desc = "DAP: evaluate expression pane" },
    { "<leader>dw",  function()
        local expr = vim.fn.input("Watch: ")
        if expr ~= "" then
          require("dapui").elements.watches.add(expr)
          require("config.term_tabs").show_ext("dap_watches")
        end
      end, desc = "DAP: add watch expression" },
    { "<leader>dpt", function() require("dap-python").test_method() end,                            desc = "DAP-Python: test method" },
    { "<leader>dpc", function() require("dap-python").test_class() end,                             desc = "DAP-Python: test class" },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    -- dap-ui instantiates every element at setup() and keeps each element's
    -- buffer live via the dap client — independent of any window. We never
    -- open dap-ui's own sidebar/tray; instead each element buffer is shown as
    -- a tab in the shared bottom terminal slot (see register_dbg_panes below).
    -- In the stacks panel, dap-ui only binds `open` (jump to frame, default `o`)
    -- and `toggle` (show/hide subtle frames, default `t`) — it never registers the
    -- `expand` action that `<CR>` defaults to, so Enter does nothing there. Add
    -- `<CR>` to `open` for the stacks element only, so Enter jumps to the frame
    -- under the cursor (variable expansion in scopes/watches keeps `<CR>` = expand).
    dapui.setup({
      element_mappings = {
        stacks = { open = { "o", "<CR>" } },
      },
    })
    require("nvim-dap-virtual-text").setup()

    -- nvim-dap has no VimLeavePre handler, so quitting nvim mid-session leaves an
    -- ATTACHED debuggee running (a neotest-vstest test host is a grandchild of nvim
    -- and reparents to init → orphan). Terminate the session on exit so the adapter
    -- kills the debuggee (clreval honors `terminate` / `disconnect{terminateDebuggee}`
    -- as of v0.0.34). `vim.wait` gives the async request a moment to flush before
    -- nvim tears the adapter job down.
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = vim.api.nvim_create_augroup("dap_terminate_on_exit", { clear = true }),
      callback = function()
        local ok, dap = pcall(require, "dap")
        if ok and dap.session() then
          pcall(dap.terminate)
          vim.wait(500, function()
            return dap.session() == nil
          end, 25)
        end
      end,
    })

    -- Installs debugpy (python) and netcoredbg (coreclr / C#) via mason.
    require("mason-nvim-dap").setup({
      ensure_installed = { "python", "coreclr" },
      automatic_installation = true,
      handlers = {},
    })

    -- Point dap-python at mason's debugpy; the *debuggee* still runs with
    -- whatever python is first on $PATH (the activated venv).
    local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
    -- `integratedTerminal` sends the debuggee's stdio to a real terminal
    -- buffer (rather than the dap-ui console), so it lands in the pane below.
    require("dap-python").setup(debugpy, { console = "integratedTerminal" })

    -- ── C# / .NET via netcoredbg (adapter type "coreclr") ──────────────────
    -- Prefer mason's binary; fall back to one on $PATH.
    local netcoredbg = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg"
    if vim.fn.executable(netcoredbg) == 0 then netcoredbg = "netcoredbg" end
    dap.adapters.coreclr = {
      type = "executable",
      command = netcoredbg,
      args = { "--interpreter=vscode" },
    }

    -- Auto-pick the built DLL from the nearest .csproj (newest build under
    -- bin/), so launching a C# target rarely needs a typed path; prompt only
    -- when nothing is built yet (run `dotnet build` first).
    local function dll_path()
      local from = vim.fs.dirname(vim.fn.expand("%:p"))
      local csproj = vim.fs.find(function(n) return n:match("%.csproj$") end,
        { upward = true, path = from, type = "file", limit = 1 })[1]
      local proj_dir = csproj and vim.fs.dirname(csproj) or vim.fn.getcwd()
      local name = csproj and vim.fn.fnamemodify(csproj, ":t:r")
      local hits = vim.fn.glob(proj_dir .. "/bin/**/" .. (name and name .. ".dll" or "*.dll"), false, true)
      table.sort(hits, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)
      if hits[1] then return hits[1] end
      return vim.fn.input("Path to dll: ", proj_dir .. "/bin/Debug/", "file")
    end

    -- `continue()` for a .cs buffer (via <leader>dd / <leader>dc / F5) picks
    -- one of these; the launch config auto-resolves the DLL above.
    dap.configurations.cs = {
      {
        type = "coreclr",
        name = "Launch (netcoredbg)",
        request = "launch",
        program = dll_path,
        cwd = "${workspaceFolder}",
        stopAtEntry = false,
      },
      {
        type = "coreclr",
        name = "Attach to process",
        request = "attach",
        processId = require("dap.utils").pick_process,
      },
    }

    -- clreval — the from-scratch, evaluation-first CoreCLR adapter (~/repos/clreval,
    -- run `cargo build --release` first). Launch -> breakpoint -> inspect real
    -- locals -> override -> evaluate full C# expressions in the eval box -> continue.
    -- Supports: stepping (in/over/out, just-my-code, async-await), conditional +
    -- hit-count breakpoints, full-expression evaluate (member/call/index/new/cast/
    -- operators) + setExpression, exception breakpoints + exceptionInfo, collection/
    -- ToString/[DebuggerDisplay] rendering, eval-cancel, and debuggee stdout as DAP
    -- `output` events (shown in the repl pane — clreval does not runInTerminal). Not
    -- supported: data breakpoints, and completions (Roslyn Phase C, in progress) —
    -- each honestly refused, never faked. Reuses the same .csproj DLL auto-resolver.
    dap.adapters.clreval = {
      type = "executable",
      command = vim.fn.expand("~/repos/clreval/target/release/clreval"),
      args = { "--dap" },
    }
    table.insert(dap.configurations.cs, {
      type = "clreval",
      name = "Launch (clreval — experimental)",
      request = "launch",
      program = dll_path,
    })
    -- Debug an NUnit/xUnit test with clreval: in a terminal run
    --   VSTEST_HOST_DEBUG=1 dotnet test --filter <YourTest>
    -- it prints "Process Id: NNNN" and waits; pick this and enter NNNN. clreval
    -- attaches, you land on a "pause" stop → continue → your test breakpoint hits.
    table.insert(dap.configurations.cs, {
      type = "clreval",
      name = "Attach to test host pid (clreval — VSTEST_HOST_DEBUG=1)",
      request = "attach",
      processId = function() return tonumber(vim.fn.input("test host pid: ")) end,
    })

    -- Spawn that terminal in the numbered terminals' single bottom slot,
    -- registered as a "debug" tab in the terminal winbar (swaps in place).
    dap.defaults.fallback.terminal_win_cmd = function()
      return require("config.term_tabs").open_dap_win()
    end

    -- Each dap-ui element (scopes / stacks / watches / breakpoints / repl)
    -- becomes its own tab in the shared bottom slot for the duration of a
    -- session, alongside the debuggee's program terminal ( debug tab).
    local g = function(cp) return vim.fn.nr2char(cp) end
    local DBG_PANES = {
      { key = "dap_scopes",      elem = "scopes",      glyph = g(0xf002), label = "scopes" },
      { key = "dap_stacks",      elem = "stacks",      glyph = g(0xf0c9), label = "stacks" },
      { key = "dap_watches",     elem = "watches",     glyph = g(0xf06e), label = "watches" },
      { key = "dap_breakpoints", elem = "breakpoints", glyph = g(0xf111), label = "breakpoints" },
      { key = "dap_repl",        elem = "repl",        glyph = g(0xf120), label = "repl" },
    }

    local function register_dbg_panes()
      local tt = require("config.term_tabs")
      for _, p in ipairs(DBG_PANES) do
        local elem = dapui.elements[p.elem]
        if elem then
          local ok, buf = pcall(elem.buffer)
          if ok and buf and vim.api.nvim_buf_is_valid(buf) then
            tt.register_ext({ key = p.key, glyph = p.glyph, label = p.label, buf = buf })
          end
        end
      end
      -- Custom "Evaluate Expression" pane (prompt buffer).
      tt.register_ext({
        key = "dap_eval",
        glyph = g(0xf1ec), -- nf-fa-calculator
        label = "eval",
        buf = require("config.dap_eval").buf(),
      })
    end

    local function clear_dbg_panes()
      local tt = require("config.term_tabs")
      for _, p in ipairs(DBG_PANES) do tt.remove_ext(p.key) end
      tt.remove_ext("dap_eval")
    end

    dap.listeners.after.event_initialized.dbg_panes = function() vim.schedule(register_dbg_panes) end
    dap.listeners.before.event_terminated.dbg_panes = function() vim.schedule(clear_dbg_panes) end
    dap.listeners.before.event_exited.dbg_panes = function() vim.schedule(clear_dbg_panes) end

    -- Floating control widget (top-right): clickable continue/pause/step/
    -- terminate buttons with hover hints, shown for the life of the session.
    local ctrl = function(fn) return function() vim.schedule(function() require("config.dap_controls")[fn]() end) end end
    dap.listeners.after.event_initialized.controls = ctrl("open")
    dap.listeners.before.event_terminated.controls = ctrl("close")
    dap.listeners.before.event_exited.controls     = ctrl("close")

    -- nvim-dap deliberately skips the jump-to-source on a `pause` stop
    -- (session.event_stopped: should_jump = reason ~= 'pause'). Do it ourselves
    -- so pausing reveals where execution stopped. Focus a real code window
    -- first, so the jump (switchbuf=uselast) lands there, not in the debug slot.
    dap.listeners.after.event_stopped.jump_on_pause = function(_, body)
      if not (body and body.reason == "pause") then return end
      local function code_win()
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.api.nvim_win_get_config(w).relative == "" then
            local b = vim.api.nvim_win_get_buf(w)
            if vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= "" then return w end
          end
        end
      end
      local tries = 0
      local function jump()
        local s = dap.session()
        if not s then return end
        if s.current_frame then
          local w = code_win()
          if w then pcall(vim.api.nvim_set_current_win, w) end
          pcall(dap.focus_frame)
        elseif tries < 20 then
          tries = tries + 1
          vim.defer_fn(jump, 40)
        end
      end
      vim.schedule(jump)
    end

    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", numhl = "" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn", numhl = "" })
    vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual", numhl = "" })
  end,
}
