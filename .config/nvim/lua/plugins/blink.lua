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
          -- easy_dotnet for NuGet package/version completion, lsp so lemminx's
          -- MSBuild schema completions (elements/attributes) still appear.
          return { 'easy_dotnet', 'lsp', 'path' }
        end

        return { 'lsp', 'path', 'snippets', 'buffer' }
      end,
      providers = {
        easy_dotnet = {
          name = 'easy-dotnet',
          module = 'easy-dotnet.completion.blink',
          enabled = is_csproj,
          -- Outrank lemminx's duplicate element items: both offer e.g.
          -- PackageReference, but easy-dotnet's self-closing attribute snippet
          -- is the one we want tab to land on.
          score_offset = 100,
        },
        lsp = {
          -- In csproj buffers, drop lemminx's element items that easy-dotnet
          -- also provides (its pair-tag variant mangles the typed <prefix);
          -- keep everything else (schema properties, attributes, values).
          transform_items = function(_, items)
            if not is_csproj() then return items end
            local dupes = {
              PackageReference = true, ProjectReference = true,
              PropertyGroup = true, ItemGroup = true,
              Target = true, Import = true, Choose = true,
            }
            return vim.tbl_filter(function(item)
              return not dupes[item.label]
            end, items)
          end,
        },
      },
    },

    fuzzy = { implementation = "prefer_rust_with_warning" }
  },
}
