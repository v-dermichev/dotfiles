---@type LazySpec
return {
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      picker = "telescope",
      timeline_indent = 2,
    },
    keys = {
      -- PR
      { "<leader>ghp", "<cmd>Octo pr list<cr>",      desc = "GitHub: PR list" },
      { "<leader>ghP", "<cmd>Octo pr create<cr>",    desc = "GitHub: PR create" },
      { "<leader>gho", "<cmd>Octo pr checkout<cr>",  desc = "GitHub: PR checkout" },
      { "<leader>ghb", "<cmd>Octo pr browser<cr>",   desc = "GitHub: open PR in browser" },
      -- Issues
      { "<leader>ghi", "<cmd>Octo issue list<cr>",   desc = "GitHub: issue list" },
      { "<leader>ghI", "<cmd>Octo issue create<cr>", desc = "GitHub: issue create" },
      -- Review
      { "<leader>ghs", "<cmd>Octo review start<cr>",    desc = "GitHub: review start" },
      { "<leader>ghr", "<cmd>Octo review resume<cr>",   desc = "GitHub: review resume" },
      { "<leader>ghm", "<cmd>Octo review submit<cr>",   desc = "GitHub: review submit" },
      { "<leader>ghd", "<cmd>Octo review discard<cr>",  desc = "GitHub: review discard" },
      { "<leader>ghc", "<cmd>Octo review comments<cr>", desc = "GitHub: review comments" },
      -- Comments / threads
      { "<leader>gha", "<cmd>Octo comment add<cr>",     desc = "GitHub: add comment", mode = { "n", "v" } },
      { "<leader>ghx", "<cmd>Octo comment delete<cr>",  desc = "GitHub: delete comment" },
      { "<leader>ght", "<cmd>Octo thread resolve<cr>",  desc = "GitHub: resolve thread" },
      { "<leader>ghT", "<cmd>Octo thread unresolve<cr>",desc = "GitHub: unresolve thread" },
      -- Misc
      { "<leader>ghS", "<cmd>Octo search<cr>",          desc = "GitHub: search" },
      { "<leader>ghn", "<cmd>Octo notification<cr>",    desc = "GitHub: notifications" },
      { "<leader>ghl", "<cmd>Octo label add<cr>",       desc = "GitHub: add label" },
      { "<leader>ghR", "<cmd>Octo reaction thumbs_up<cr>", desc = "GitHub: react 👍" },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  },
}
