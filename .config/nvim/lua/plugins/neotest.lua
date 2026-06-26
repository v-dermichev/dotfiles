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
  },
  keys = {
    { "<leader>tr", function() require("neotest").run.run() end,                       desc = "Test: run nearest (under cursor)" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end,      desc = "Test: run file" },
    { "<leader>ta", function() require("neotest").run.run(vim.fn.getcwd()) end,         desc = "Test: run all" },
    { "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end,    desc = "Test: debug nearest" },
    { "<leader>tl", function() require("neotest").run.run_last() end,                   desc = "Test: run last" },
    { "<leader>tx", function() require("neotest").run.stop() end,                       desc = "Test: stop" },
    { "<leader>ts", function() require("neotest").summary.toggle() end,                 desc = "Test: summary panel" },
    { "<leader>to", function() require("neotest").output.open({ enter = true }) end,    desc = "Test: show output" },
    { "<leader>tO", function() require("neotest").output_panel.toggle() end,            desc = "Test: output panel" },
    { "]t",         function() require("neotest").jump.next({ status = "failed" }) end, desc = "Test: next failed" },
    { "[t",         function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Test: prev failed" },
  },
  -- Load when a Python file is opened (not only on first <leader>t key) so the
  -- gutter test markers appear without having to run a test first.
  ft = { "python" },
  config = function()
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

    -- On opening a Python file, force discovery of its tests so the gutter
    -- markers render immediately instead of only after the first run.
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "python",
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
