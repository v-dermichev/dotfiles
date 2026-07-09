return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    -- Hide langmapper's Russian-layout twins from the hint popup: show only the
    -- English mappings. The twins are the only maps whose lhs contains Cyrillic
    -- (UTF-8 lead bytes 0xD0/0xD1); English maps are pure ASCII. The maps still
    -- work in Russian layout — this only trims the which-key display.
    filter = function(mapping)
      return not (mapping.lhs and mapping.lhs:find("[\208\209]"))
    end,
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
