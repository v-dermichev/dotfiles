---@type LazySpec
-- Docked file-tree sidebar on the left. Non-floating, opens on start and
-- stays until toggled. Pairs with the horizontal (botright, full-width)
-- toggleterm: the terminal spans edge-to-edge along the bottom while the
-- tree occupies a fixed slice of the top-left.
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false, -- load at startup so the auto-open below has the command ready
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "<leader>e", "<cmd>Neotree toggle left<cr>", desc = "File tree: toggle" },
    { "<leader>E", "<cmd>Neotree reveal left<cr>", desc = "File tree: reveal current file" },
  },
  opts = {
    close_if_last_window = false, -- never auto-close; the pane is persistent
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,
    window = {
      position = "left",
      width = 32, -- fixed slice of the left side
      mappings = {
        ["l"] = "open", -- unfold dir / open file
        ["h"] = "close_node", -- fold dir
      },
    },
    filesystem = {
      follow_current_file = { enabled = true, leave_dirs_open = true },
      use_libuv_file_watcher = true, -- live-update the tree on disk changes
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    default_component_configs = {
      indent = { with_expanders = true },
    },
  },
  init = function()
    local group = vim.api.nvim_create_augroup("NeotreeAutoOpen", { clear = true })

    local TREE_WIDTH = 32 -- keep in sync with opts.window.width below

    -- Force a deterministic docked layout: neo-tree pinned to the far left,
    -- an editor pane to its right, cursor in the editor. The autoload race
    -- (session restore + async neo-tree open) can otherwise leave the tree on
    -- the right or as the only window; this normalizes whatever it produced.
    local function normalize_layout()
      local tree, editor
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then
          tree = w
        else
          editor = editor or w
        end
      end

      -- No editor pane (collapsed session / no-arg launch): split an empty one.
      if not editor then
        vim.cmd("botright vsplit | enew")
        editor = vim.api.nvim_get_current_win()
      end

      -- Tree not leftmost: shove it to the far left and restore its width.
      if tree and vim.api.nvim_win_get_position(tree)[2] ~= 0 then
        vim.api.nvim_set_current_win(tree)
        vim.cmd("wincmd H")
        pcall(vim.api.nvim_win_set_width, tree, TREE_WIDTH)
      end

      -- Land the cursor in the editor, not the tree.
      if vim.api.nvim_win_is_valid(editor) then
        vim.api.nvim_set_current_win(editor)
      end
    end

    -- Open the docked sidebar via "focus" (not "show" — "show" triggers
    -- neo-tree's async hop-back callback, which crashes with "Invalid window
    -- id" when the captured startup window is gone), then normalize. The
    -- second pass runs after neo-tree's own deferred callback re-grabs the
    -- tree, so the final state is tree-left / cursor-in-editor.
    local function open_sidebar()
      -- Root the tree at the current cwd. On the VimEnter pass this is still
      -- the launch dir, but the SessionLoadPost pass runs after the session's
      -- `cd`, so it re-roots the (already-open) tree onto the restored project
      -- instead of leaving it showing $HOME. Passing `dir` re-navigates even
      -- when neo-tree is already open.
      require("neo-tree.command").execute({
        action = "focus",
        position = "left",
        dir = vim.fn.getcwd(),
      })
      vim.schedule(function()
        normalize_layout()
        vim.schedule(normalize_layout)
      end)
    end

    -- Auto-open on start. Skipped when nvim is piped stdin (git/man scratch
    -- buffer). When a session is autoloaded (neovim-project), it replaces the
    -- whole layout on VimEnter and fires User SessionLoadPost, which re-opens
    -- the tree below — so a VimEnter open here is harmless/idempotent.
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      callback = function()
        if vim.fn.argc() == -1 then return end -- reading from stdin
        local first = vim.fn.argv(0)
        -- If nvim was launched on a directory, neo-tree already takes over.
        if type(first) == "string" and vim.fn.isdirectory(first) == 1 then
          require("neo-tree.command").execute({ action = "show", position = "left", dir = first })
        else
          open_sidebar()
        end
      end,
    })

    -- neovim-project / session-manager force-deletes every buffer and
    -- re-sources the saved layout when loading a project (both at startup and
    -- on a runtime switch), which drops the tree. Re-open it fresh once the
    -- session has finished loading.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "SessionLoadPost",
      callback = function()
        vim.schedule(open_sidebar)
      end,
    })

    -- Don't persist neo-tree windows into the session file — they restore as
    -- broken empty panes. Close them before the session is written.
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "SessionSavePre",
      callback = function()
        pcall(function()
          require("neo-tree.command").execute({ action = "close" })
        end)
      end,
    })
  end,
}
