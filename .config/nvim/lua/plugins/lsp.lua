return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  -- lazy = true,
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
  },
  config = function()
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local lspconfig = require('lspconfig')

    -- Lua
    vim.lsp.config("lua_ls", {
      capabilities = capabilities,
      settings = {
        Lua = {
          runtime = {
            version = 'LuaJIT', -- Use LuaJIT for Neovim
          },
          diagnostics = {
            globals = { 'vim' }, -- Recognize `vim` as a global
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true), -- Make LSP aware of Neovim runtime
            checkThirdParty = false,                           -- Disable third-party library warnings
          },
          telemetry = {
            enable = false, -- Disable telemetry for privacy
          },
        },
      },
    })
    -- local utils = require("my.utils");

    vim.lsp.config("ts_ls", {
      capabilities = capabilities,
    })

    vim.lsp.config("clangd", {})
    vim.lsp.config("rust_analyzer", {
      -- cmd = { "/home/ricardo/.cargo/bin/rust-analyzer" }
    })
    vim.lsp.config("clangd", {})
    vim.lsp.config("jsonls", {
      filetypes = { "json", "jsonc" },
    })
    vim.lsp.config("taplo", {
      root_markers = { "taplo.toml", ".taplo.toml", "pyproject.toml", "Cargo.toml", ".git" },
      settings = {
        evenBetterToml = {
          schema = {
            enabled = true,
            catalogs = { "https://taplo.tamasfe.dev/schema_index.json" },
            associations = {
              ["pyproject\\.toml$"]   = "https://json.schemastore.org/pyproject.json",
              ["Cargo\\.toml$"]       = "https://json.schemastore.org/cargo.json",
              ["ruff\\.toml$"]        = "https://json.schemastore.org/ruff.json",
              ["\\.ruff\\.toml$"]     = "https://json.schemastore.org/ruff.json",
              ["rustfmt\\.toml$"]     = "https://json.schemastore.org/rustfmt.json",
              ["\\.rustfmt\\.toml$"]  = "https://json.schemastore.org/rustfmt.json",
              ["rust-toolchain\\.toml$"] = "https://json.schemastore.org/rust-toolchain.json",
              ["uv\\.toml$"]          = "https://raw.githubusercontent.com/astral-sh/uv/main/uv.schema.json",
              ["netlify\\.toml$"]     = "https://json.schemastore.org/netlify.json",
              ["wrangler\\.toml$"]    = "https://json.schemastore.org/wrangler.json",
              ["yazi/yazi\\.toml$"]   = "https://yazi-rs.github.io/schemas/yazi.json",
            },
          },
        },
      },
    })
    vim.lsp.config("powershell_es", {})
    vim.lsp.config("astro", {})

    -- local jdtls_location = utils.get_jdtls_location();
    -- print("jdtls" .. jdtls_location)
    -- vim.lsp.config('jdtls', { cmd = { jdtls_location } })

    local sysname = vim.uv.os_uname().sysname:lower()
    local iswin = not not (sysname:find("windows") or sysname:find("mingw"))
    vim.lsp.config("roslyn_ls", {
      cmd = {
        iswin and "roslyn.cmd" or "roslyn",
        "--logLevel=Information",
        "--extensionLogDirectory=" .. vim.fn.stdpath("log"),
        "--stdio",
      },
      settings = {
        roslyn = {
          enableAnalyzersSupport = true,
          enableEditorConfigSupport = true,
          diagnostics = { mode = "all" },
        },
      },
      capabilities = capabilities,
    })

    -- Turn on inlay hints for any LSP client that supports them.
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then return end
        local ok, supported = pcall(function()
          if type(client.supports_method) == "function" then
            return client:supports_method("textDocument/inlayHint")
          end
          return client.server_capabilities
            and client.server_capabilities.inlayHintProvider ~= nil
        end)
        if ok and supported then
          pcall(vim.lsp.inlay_hint.enable, true, { bufnr = args.buf })
        end
      end,
    })

    vim.lsp.config("lemminx", {
      filetypes = { "xml", "axaml", "xsd", "xslt", "csproj" },
    })

    vim.lsp.config("editorconfig-checker", {
      filetypes = { ".editorconfig" },
    })

    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
      pattern = "*.axaml",
      callback = function()
        vim.bo.filetype = "xml"
      end,
    })
    --
  end
}
