return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    -- Hide langmapper's Russian-layout twins from the hint popup: show only the
    -- English mappings. The twins are the only maps whose lhs contains Cyrillic
    -- (UTF-8 lead bytes 0xD0/0xD1); English maps are pure ASCII. Navigation in
    -- Russian still works via the getchar translation installed in config().
    filter = function(mapping)
      return not (mapping.lhs and mapping.lhs:find("[\208\209]"))
    end,
  },
  -- which-key reads keys with getcharstr(), which bypasses 'langmap'. So once the
  -- popup takes over, a Russian keypress isn't translated and doesn't match the
  -- English tree (plugin `keys=` maps have no Cyrillic twins), which breaks
  -- navigation (`<leader>в` falls through to the `d` delete operator). Translate
  -- the char which-key reads through the same ru->en map as `langmap`, so Russian
  -- keys navigate the English nodes directly — no twins needed, display stays English.
  config = function(_, opts)
    require("which-key").setup(opts)

    local layouts = {
      { [[`qwertyuiop[]asdfghjkl;'zxcvbnm]], [[ёйцукенгшщзхъфывапролджэячсмить]] },
      { [[~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>]], [[ËЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ]] },
    }
    local ru_to_en = {}
    for _, pair in ipairs(layouts) do
      local en = vim.fn.split(pair[1], "\\zs")
      local ru = vim.fn.split(pair[2], "\\zs")
      for i, ru_ch in ipairs(ru) do
        if en[i] then ru_to_en[ru_ch] = en[i] end
      end
    end

    local state = require("which-key.state")
    local orig_getchar = state.getchar
    state.getchar = function()
      local ok, char = orig_getchar()
      if ok and type(char) == "string" then
        char = ru_to_en[char] or char
      end
      return ok, char
    end
  end,
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
