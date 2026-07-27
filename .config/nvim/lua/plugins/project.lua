return {
  "coffebar/neovim-project",
  keys = {
    { "<leader>pd", "<cmd>NeovimProjectDiscover<cr>", desc = "Project: discover" },
    { "<leader>ph", "<cmd>NeovimProjectHistory<cr>", desc = "Project: history" },
  },
  opts = {
    projects = { -- define project roots
      "~/projects/*",
      "~/repos/*",
      "~/repos/*/*",
      "~/repos/*/*/*",
      "~/.config/*",
      "~/.config/*/*",
    },
    picker = {
      type = "telescope", -- one of "telescope", "fzf-lua", or "snacks"
    }
  },
  init = function()
    -- enable saving the state of plugins in the session
    vim.opt.sessionoptions:append("globals") -- save global variables that start with an uppercase letter and contain at least one lowercase letter.
  end,
  dependencies = {
    { "nvim-lua/plenary.nvim" },
    -- optional picker (version pinned in plugins/telescope.lua — don't re-pin here)
    { "nvim-telescope/telescope.nvim" },
    -- optional picker
    { "ibhagwan/fzf-lua" },
    -- optional picker
    { "folke/snacks.nvim" },
    { "Shatur/neovim-session-manager" },
  },
  lazy = false,
  priority = 100,
}
