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
    config = function(_, opts)
      require("octo").setup(opts)
      -- Octo already opens the changed-files panel as a bottom split; adopt it
      -- into the shared terminal slot's winbar so it appears as a "PR files"
      -- tab alongside the terminals/debug/tests. Octo keeps managing the
      -- window itself (it tracks its own winid for the review layout), so this
      -- is display-level adoption rather than a full slot takeover.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "octo_panel",
        callback = function(args)
          vim.schedule(function()
            local ok, tt = pcall(require, "config.term_tabs")
            if ok then
              tt.register_ext({
                key = "octo",
                glyph = vim.fn.nr2char(0xf09b), -- nf-fa-github
                label = "PR files",
                buf = args.buf,
                -- When the slot reopens the panel in a fresh window, point
                -- octo's file panel at it so j/k navigation and <CR> (which
                -- read the cursor from file_panel.winid) keep working.
                on_show = function(win)
                  local ok, reviews = pcall(require, "octo.reviews")
                  if not ok then return end
                  local review = reviews.get_current_review and reviews.get_current_review()
                  local fp = review and review.layout and review.layout.file_panel
                  if fp then fp.winid = win end
                end,
                -- The tab's close glyph (×) closes the whole review workspace
                -- (file panel + diff windows), via octo's layout tabclose.
                on_close = function()
                  local ok, reviews = pcall(require, "octo.reviews")
                  if not ok then return end
                  local review = reviews.get_current_review and reviews.get_current_review()
                  if review and review.layout then
                    pcall(function() review.layout:close() end)
                  end
                end,
              })
            end
          end)
        end,
      })
    end,
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
      { "<leader>ghq", "<cmd>Octo review close<cr>",    desc = "GitHub: close review workspace" },
      -- Comments / threads
      -- Normal mode: comment on the cursor line. Visual mode must go through
      -- `:` (not <cmd>) so leaving visual passes the selection as the command
      -- range (line1/line2) that Octo reads — <cmd> keeps stale '<,'> marks
      -- and comments on the previous selection instead.
      { "<leader>gha", "<cmd>Octo comment add<cr>", desc = "GitHub: add comment",             mode = "n" },
      { "<leader>gha", ":Octo comment add<cr>",     desc = "GitHub: add comment (selection)", mode = "x", silent = true },
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
