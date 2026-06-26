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
    { "<leader>dc",  function() require("dap").continue() end,                                      desc = "DAP: continue" },
    { "<F5>",        function() require("dap").continue() end,                                      desc = "DAP: continue" },
    { "<leader>di",  function() require("dap").step_into() end,                                     desc = "DAP: step into" },
    { "<F11>",       function() require("dap").step_into() end,                                     desc = "DAP: step into" },
    { "<leader>do",  function() require("dap").step_over() end,                                     desc = "DAP: step over" },
    { "<F10>",       function() require("dap").step_over() end,                                     desc = "DAP: step over" },
    { "<leader>dO",  function() require("dap").step_out() end,                                      desc = "DAP: step out" },
    { "<leader>dr",  function() require("dap").repl.toggle() end,                                   desc = "DAP: toggle REPL" },
    { "<leader>dl",  function() require("dap").run_last() end,                                      desc = "DAP: run last" },
    { "<leader>dt",  function() require("dap").terminate() end,                                     desc = "DAP: terminate" },
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
    dapui.setup()
    require("nvim-dap-virtual-text").setup()

    -- Installs debugpy and registers the python adapter via mason.
    require("mason-nvim-dap").setup({
      ensure_installed = { "python" },
      automatic_installation = true,
      handlers = {},
    })

    -- Point dap-python at mason's debugpy; the *debuggee* still runs with
    -- whatever python is first on $PATH (the activated venv).
    local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
    -- `integratedTerminal` sends the debuggee's stdio to a real terminal
    -- buffer (rather than the dap-ui console), so it lands in the pane below.
    require("dap-python").setup(debugpy, { console = "integratedTerminal" })

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

    vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", numhl = "" })
    vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn", numhl = "" })
    vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual", numhl = "" })
  end,
}
