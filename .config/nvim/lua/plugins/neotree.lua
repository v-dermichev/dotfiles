---@type LazySpec
-- Docked file-tree sidebar on the left. Non-floating, opens on start and
-- stays until toggled. Pairs with the horizontal (botright, full-width)
-- toggleterm: the terminal spans edge-to-edge along the bottom while the
-- tree occupies a fixed slice of the top-left.
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false, -- load at startup so the auto-open below has the command ready
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "<leader>e", "<cmd>Neotree toggle left<cr>", desc = "File tree: toggle" },
    { "<leader>E", "<cmd>Neotree reveal left<cr>", desc = "File tree: reveal current file" },
  },
  opts = {
    close_if_last_window = false, -- never auto-close; the pane is persistent
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,
    window = {
      position = "left",
      width = 32, -- fixed slice of the left side
      mappings = {
        ["l"] = "open", -- unfold dir / open file
        ["h"] = "close_node", -- fold dir
      },
    },
    filesystem = {
      follow_current_file = { enabled = true, leave_dirs_open = true },
      use_libuv_file_watcher = true, -- live-update the tree on disk changes
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    default_component_configs = {
      indent = { with_expanders = true },
    },
  },
  init = function()
    -- Auto-open the sidebar on start, then hand focus back to the editor so
    -- the cursor lands in your file, not the tree. Skipped when nvim is
    -- piped stdin (e.g. `git` / `man` opening a scratch buffer).
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("NeotreeAutoOpen", { clear = true }),
      callback = function()
        if vim.fn.argc() == -1 then return end -- reading from stdin
        local first = vim.fn.argv(0)
        -- If nvim was launched on a directory, neo-tree already takes over;
        -- otherwise show the sidebar and return to the file window.
        if type(first) == "string" and vim.fn.isdirectory(first) == 1 then
          require("neo-tree.command").execute({ action = "show", position = "left", dir = first })
        else
          require("neo-tree.command").execute({ action = "show", position = "left" })
          vim.schedule(function()
            pcall(vim.cmd.wincmd, "p") -- jump back to previous (editor) window
          end)
        end
      end,
    })
  end,
}
