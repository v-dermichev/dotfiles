local function is_csproj()
  return vim.api.nvim_buf_get_name(0):match("%.csproj$") ~= nil
end

return {
  'saghen/blink.cmp',
  dependencies = { 'rafamadriz/friendly-snippets' },

  version = '1.*',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
	    keymap = {
	      preset = 'super-tab',
	      ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
	      ['<C-j>'] = { 'select_next', 'fallback' },
	      ['<C-k>'] = { 'select_prev', 'fallback' },
	    },

    appearance = {
      nerd_font_variant = 'mono'
    },

	    completion = {
	      menu = { border = 'rounded' },
	      trigger = { show_on_trigger_character = true },
	      documentation = { auto_show = true, window = { border = 'rounded' } },
	    },

    -- Native signature help while typing call arguments (replaces lsp_signature.nvim).
    signature = { enabled = true, window = { border = 'rounded' } },

    sources = {
      default = function()
        if is_csproj() then
          return { 'easy_dotnet' }
        end

        return { 'lsp', 'path', 'snippets', 'buffer' }
      end,
      providers = {
        easy_dotnet = {
          name = 'easy-dotnet',
          module = 'easy-dotnet.completion.blink',
          enabled = is_csproj,
        },
      },
    },

    fuzzy = { implementation = "prefer_rust_with_warning" }
  },
}
