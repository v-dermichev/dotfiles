-- Test discovery + runner. neotest places pass/fail/running signs in the
-- gutter next to each test and runs the test under the cursor. The python
-- adapter uses pytest with the active venv's interpreter (see
-- lua/config/venv.lua) and reuses debugpy for debugging a test.
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "nvim-neotest/neotest-python",
    "Nsidorenco/neotest-vstest",
  },
  keys = {
    { "<leader>tr", function() require("neotest").run.run() end,                     desc = "Test: run nearest (under cursor)" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end,   desc = "Test: run file" },
    { "<leader>ta", function() require("neotest").run.run(vim.fn.getcwd()) end,      desc = "Test: run all" },
    { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Test: debug nearest (clreval)" },
    -- Same debug-nearest, but forces the OLD debugger (netcoredbg) for this one
    -- run via a one-shot override the strategy wrapper below consumes — for
    -- comparing clreval against netcoredbg on the identical test/breakpoint.
    {
      "<leader><leader>td",
      function()
        vim.g.neotest_vstest_debug_backend = { type = "coreclr", request = "attach" }
        require("neotest").run.run({ strategy = "dap" })
      end,
      desc = "Test: debug nearest (netcoredbg — comparison)"
    },
    { "<leader>tl", function() require("neotest").run.run_last() end,                   desc = "Test: run last" },
    { "<leader>tx", function() require("neotest").run.stop() end,                       desc = "Test: stop" },
    { "<leader>ts", function() require("neotest").summary.toggle() end,                 desc = "Test: summary panel" },
    { "<leader>to", function() require("neotest").output.open({ enter = true }) end,    desc = "Test: show output" },
    { "<leader>tO", function() require("neotest").output_panel.toggle() end,            desc = "Test: output panel" },
    { "]t",         function() require("neotest").jump.next({ status = "failed" }) end, desc = "Test: next failed" },
    { "[t",         function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Test: prev failed" },
  },
  -- Load when a Python or C# file is opened (not only on first <leader>t key)
  -- so the gutter test markers appear without having to run a test first.
  ft = { "python", "cs" },
  config = function()
    -- neotest-vstest reads its options from this global, so set it before the
    -- adapter is required below. `<leader>td` (strategy="dap") starts the test
    -- host in debug-wait mode and attaches this adapter by pid, releasing the
    -- host after configurationDone — so it runs straight to the breakpoint.
    -- clreval consumes the attach-synchronization pause and lands on the first
    -- real stop (v0.0.16), which is why it fits here. To fall back to netcoredbg,
    -- set type = "coreclr" (and drop `request`, which coreclr infers).
    vim.g.neotest_vstest = {
      dap_settings = { type = "clreval", request = "attach" },
      -- The result-file wait is a fixed wall-clock timeout that keeps counting
      -- while the test host is paused at a breakpoint under `<leader>td`. The
      -- default 150s trips mid-debug (e.g. while inspecting the DAP Scopes
      -- panel), throwing an nio "result file does not exist" assert even though
      -- the run is healthy — just halted. Raise it past any realistic pause.
      timeout_ms = 30 * 60 * 1000, -- 30 min
    }

    -- neotest-vstest bakes its dap `type` at adapter-construction time, so a plain
    -- runtime swap can't retarget the backend. The debug strategy factory is,
    -- however, `require`d fresh for every debug run — so wrap that module once and
    -- let it apply a ONE-SHOT backend override (set by `<leader><leader>td`),
    -- consumed on the next spec build. This keeps a single registered adapter
    -- (no duplicate discovery trees) while allowing a per-run backend choice.
    local orig_debugger = require("neotest-vstest.strategies.vstest_debugger")
    package.loaded["neotest-vstest.strategies.vstest_debugger"] = function(dap_config)
      local override = vim.g.neotest_vstest_debug_backend
      vim.g.neotest_vstest_debug_backend = nil -- one-shot: applies to this run only
      if override then
        dap_config = vim.tbl_extend("force", dap_config, override)
      end
      return orig_debugger(dap_config)
    end

    local nio = require("nio")
    -- Captured at consumer init so the FileType autocmd below can force
    -- discovery of a freshly-opened buffer (which boots the client and makes
    -- the status consumer render the `` test markers).
    local client = nil

    require("neotest").setup({
      adapters = {
        require("neotest-python")({
          runner = "pytest",
          dap = { justMyCode = false },
        }),
        -- C# / .NET via VSTest — framework-agnostic (NUnit/xUnit/MSTest), auto-
        -- discovers the solution, and debugs a test through the coreclr adapter
        -- (see dap_settings above + lua/plugins/dap.lua).
        require("neotest-vstest"),
      },
      -- The output panel is a terminal buffer; open it into the shared bottom
      -- terminal slot (managed by config.term_tabs) so it appears as a "tests"
      -- tab alongside the numbered terminals and the debug terminal.
      output_panel = {
        open = "lua require('config.term_tabs').open_panel_slot()",
      },
      consumers = {
        -- Stream test output into the bottom terminal pane on every run.
        output_panel_autoopen = function(c)
          c.listeners.run = function()
            vim.schedule(function()
              require("neotest").output_panel.open()
              vim.defer_fn(function()
                require("config.term_tabs").scroll_ext_bottom("neotest")
              end, 150)
            end)
          end
          return {}
        end,
        -- Capture the client so we can kick off discovery on file open.
        capture_client = function(c)
          client = c
          return {}
        end,
      },
    })

    -- neotest-vstest models TestCase/Theory parents as type "parameterized";
    -- neotest's status consumer falls back to pos.type for positions without
    -- results and places a "neotest_<type>" sign it never defined for that
    -- vstest-specific type — E155 spam on entering files with parameterized
    -- tests. Define it like the namespace sign (both are grouping nodes).
    local ncfg = require("neotest.config")
    vim.fn.sign_define("neotest_parameterized", {
      text = ncfg.icons.namespace,
      texthl = ncfg.highlights.namespace,
    })

    -- On opening a Python or C# file, force discovery of its tests so the
    -- gutter markers render immediately instead of only after the first run.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "python", "cs" },
      callback = function(ev)
        local file = vim.api.nvim_buf_get_name(ev.buf)
        if file == "" then return end
        vim.defer_fn(function()
          if not client then return end
          nio.run(function()
            pcall(function() client:get_position(file, {}) end)
          end)
        end, 100)
      end,
    })

    -- Register neotest's output panel as a slot tab once it appears.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "neotest-output-panel",
      callback = function(args)
        vim.schedule(function()
          require("config.term_tabs").register_ext({
            key = "neotest",
            glyph = "\xef\x83\x83", -- nf-fa-flask (U+F0C3)
            label = "tests",
            buf = args.buf,
            follow = true, -- keep the view pinned to the latest output
          })
        end)
      end,
    })
  end,
}
