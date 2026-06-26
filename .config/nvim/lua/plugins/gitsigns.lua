-- Git gutter signs + hunk staging/preview/blame (the IDE "change bar").
-- snacks doesn't provide signcolumn git markers, so gitsigns owns this.
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    on_attach = function(bufnr)
      local gs = require("gitsigns")
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      map("n", "]h", function() gs.nav_hunk("next") end, "Next git hunk")
      map("n", "[h", function() gs.nav_hunk("prev") end, "Prev git hunk")

      map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
      map("v", "<leader>gs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage selection")
      map("v", "<leader>gr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection")
      map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
      map("n", "<leader>gd", gs.diffthis, "Diff this")
      map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, "Blame line")
      map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle line blame")
    end,
  },
}
