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
    local has_blink, blink = pcall(require, "blink.cmp")
    if has_blink then
      capabilities = blink.get_lsp_capabilities(capabilities)
    end

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
    vim.lsp.config("rust_analyzer", {})
    vim.lsp.config("jsonls", {
      filetypes = { "json", "jsonc" },
    })

    -- YAML. schemaStore stays on so generic YAML (compose, actions, k8s)
    -- still auto-resolves; the explicit `schemas` map pins GitLab CI files to
    -- GitLab's own schema (fresher than the SchemaStore mirror). customTags
    -- whitelists the `!reference` tag GitLab CI uses, which yamlls otherwise
    -- flags as an unknown-tag error.
    vim.lsp.config("yamlls", {
      capabilities = capabilities,
      settings = {
        yaml = {
          schemaStore = { enable = true, url = "https://www.schemastore.org/api/json/catalog.json" },
          schemas = {
            ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] =
              { ".gitlab-ci.yml", "*.gitlab-ci.yml" },
          },
          customTags = { "!reference sequence" },
          validate = true,
          completion = true,
          hover = true,
        },
      },
    })

    -- Embedded-language servers for otter.nvim (`# language=bash|sql` strings).
    vim.lsp.config("bashls", { capabilities = capabilities })
    vim.lsp.config("sqls", { capabilities = capabilities })
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

    -- Markdown (remark-language-server). It requests workspace configuration
    -- under the "remark" section on every document; neovim answers null when
    -- no settings exist, and the server's unified-language-server core then
    -- crashes on `Boolean(raw.requireConfig)` (null deref), quitting on every
    -- .md open. Supplying the section — requireConfig=false so it lints
    -- without demanding a .remarkrc — gives it a non-null object to read.
    vim.lsp.config("remark_ls", {
      capabilities = capabilities,
      settings = {
        remark = {
          requireConfig = false,
        },
      },
    })

    -- Python: ty for type-checking / hover / completion, ruff for
    -- linting, formatting and code actions. Both discover the active
    -- interpreter from $VIRTUAL_ENV (see lua/config/venv.lua).
    vim.lsp.config("ty", {
      capabilities = capabilities,
    })
    vim.lsp.config("ruff", {
      capabilities = capabilities,
    })

    -- Let ty own hover so it doesn't fight with ruff's (ruff only emits
    -- "noqa" style hovers); keeps a single source of truth for K.
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "ruff" then
          client.server_capabilities.hoverProvider = false
        end
      end,
    })

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

    local nvim_config = vim.fn.stdpath("config")

    vim.lsp.config("lemminx", {
      filetypes = { "xml", "axaml", "xsd", "xslt", "csproj", "slnx" },
      settings = {
        xml = {
          catalogs = {
            nvim_config .. "/schemas/catalog.xml",
          },
          fileAssociations = {
            {
              pattern = "**/*.csproj",
              systemId = nvim_config .. "/schemas/Microsoft.Build.CommonTypes.xsd",
            },
            {
              pattern = "**/*.slnx",
              systemId = nvim_config .. "/schemas/Slnx.xsd",
            },
          },
        },
      },
    })
    vim.lsp.enable("lemminx")

    vim.lsp.config("editorconfig-checker", {
      filetypes = { ".editorconfig" },
    })

    --
  end
}
