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
    -- Don't open files into special panes (default covers terminal/trouble/qf;
    -- dbui/dbout added since the DB drawer docks right below the tree and was
    -- swallowing file opens).
    open_files_do_not_replace_types = { "terminal", "trouble", "qf", "dbui", "dbout" },
    window = {
      position = "left",
      width = 32,                                      -- fixed slice of the left side
      mappings = {
        ["q"] = { "quick_open", nowait = true },       -- launch default xdg app, floating
        ["Q"] = { "quick_open_tiled", nowait = true }, -- launch default xdg app, tiled
        ["l"] = "open",                                -- unfold dir / open file in editor
        ["h"] = "close_node",                          -- fold dir
        ["o"] = { "open_with", nowait = true },        -- xdg "open with" menu; launches floating
        ["O"] = { "open_with_tiled", nowait = true },  -- same menu; launches tiled
        ["."] = "set_root",                            -- re-root the tree at the hovered directory
        ["<bs>"] = "navigate_up",                      -- re-root one level up (undo set_root / go back)
        ["w"] = { "change_dir", nowait = true },       -- :cd Neovim to the hovered directory
      },
    },
    commands = {
      open_with = function(state)
        require("config.open_with").open_with(state, { float = true })
      end,
      open_with_tiled = function(state)
        require("config.open_with").open_with(state, { float = false })
      end,
      quick_open = function(state)
        require("config.open_with").quick(state, { float = true })
      end,
      quick_open_tiled = function(state)
        require("config.open_with").quick(state, { float = false })
      end,
      -- Change Neovim's working directory to the hovered folder (or the parent
      -- dir of a hovered file). Global :cd, so terminals / pickers / LSP root
      -- all follow. Pair with `.` (set_root) to also re-root the tree there.
      change_dir = function(state)
        local node = state.tree:get_node()
        if not node then return end
        local dir = node.type == "directory" and node.path
          or vim.fn.fnamemodify(node.path, ":h")
        vim.cmd("cd " .. vim.fn.fnameescape(dir))
        vim.notify("cwd → " .. dir)
      end,
    },
    filesystem = {
      follow_current_file = { enabled = true, leave_dirs_open = true },
      use_libuv_file_watcher = true, -- live-update the tree on disk changes
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
      components = {
        -- Badge on files an external agent changed since they were last
        -- viewed, and on directories for as long as any such file remains
        -- below them (config.autosave marks paths via the Claude Code hook;
        -- opening a file clears its mark, the dir badge falls off with the
        -- last one).
        agent_mark = function(config, node, state)
          local autosave = require("config.autosave")
          local marked = (node.type == "file" and autosave.is_marked(node.path))
            or (node.type == "directory"
              and autosave.has_marked_below(node.path))
          if marked then
            return { text = " 󰚩", highlight = "NeoTreeAgentMark" }
          end
          return {}
        end,
      },
    },
    default_component_configs = {
      indent = { with_expanders = true },
      -- Keep the last column blank: wide right-aligned glyphs (agent_mark 󰚩)
      -- otherwise get clipped against the window separator.
      container = { right_padding = 1 },
    },
  },
  -- Inject agent_mark right after the name in the stock file and directory
  -- renderers, copied from neo-tree.defaults so everything else stays default.
  config = function(_, opts)
    local defaults = require("neo-tree.defaults")
    opts.renderers = opts.renderers or {}
    for _, kind in ipairs({ "file", "directory" }) do
      local renderer = vim.deepcopy(defaults.renderers[kind])
      for _, comp in ipairs(renderer) do
        if comp[1] == "container" then
          local content = comp.content or {}
          -- Right-aligned in a high layer, like the git_status markers: the
          -- container pins these to the right edge and truncates long names
          -- underneath them, so the badge is never covered. Placed just
          -- before git_status to sit beside those markers.
          local pos = #content + 1
          for i, c in ipairs(content) do
            if c[1] == "git_status" then
              pos = i
              break
            end
          end
          table.insert(content, pos, { "agent_mark", zindex = 20, align = "right" })
        end
      end
      opts.renderers[kind] = renderer
    end
    require("neo-tree").setup(opts)
  end,
  init = function()
    vim.api.nvim_set_hl(0, "NeoTreeAgentMark", { link = "DiagnosticWarn", default = true })
    local group = vim.api.nvim_create_augroup("NeotreeAutoOpen", { clear = true })

    local TREE_WIDTH = 32 -- keep in sync with opts.window.width below

    -- Force a deterministic docked layout: neo-tree pinned to the far left,
    -- an editor pane to its right, cursor in the editor. The autoload race
    -- (session restore + async neo-tree open) can otherwise leave the tree on
    -- the right or as the only window; this normalizes whatever it produced.
    local function normalize_layout()
      local tree, editors, ghosts = nil, {}, {}
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(w).relative == "" then
          local b = vim.api.nvim_win_get_buf(w)
          if vim.bo[b].filetype == "neo-tree" then
            tree = w
          elseif vim.bo[b].buftype == ""
            and vim.api.nvim_buf_get_name(b) == ""
            and not vim.bo[b].modified
            and vim.api.nvim_buf_line_count(b) == 1
            and (vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] or "") == "" then
            -- Empty scratch pane — either a bare launch or the fallback split
            -- created below on an earlier pass.
            table.insert(ghosts, w)
          else
            table.insert(editors, w)
          end
        end
      end

      -- When a real editor exists, close any scratch leftovers: the fallback
      -- split below can race session restore, which then brings its own editor
      -- and squeezes the fallback into a 1-column ghost at the screen edge.
      local editor = editors[1]
      if editor then
        for _, g in ipairs(ghosts) do pcall(vim.api.nvim_win_close, g, false) end
      else
        editor = ghosts[1]
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
      -- Late sweep: the session-restore / neo-tree async dance can produce its
      -- last window after both scheduled passes (leaving a squeezed ghost pane);
      -- normalize is idempotent, so one more pass after things settle is safe.
      vim.defer_fn(normalize_layout, 300)
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

    -- Reopening the sidebar while a terminal / output pane is docked at the
    -- bottom nests that pane inside the editor column (losing its full width)
    -- and stretches the tree full-height beside it. Re-dock the pane to
    -- full-width bottom, restoring the tree-and-editor-share-the-top,
    -- terminal-spans-the-bottom layout. Do it synchronously in the same event
    -- tick the tree window is created, before the screen redraws, so the pane
    -- never flashes at editor width. A scheduled pass follows as an idempotent
    -- safety net for any path where the synchronous move is blocked (it no-ops
    -- once the pane is already full width).
    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = group,
      callback = function(args)
        if vim.bo[args.buf].filetype ~= "neo-tree" then return end
        -- Canonical geometry (slot full-width bottom, DB drawer under the
        -- tree, …) is enforced by config.layout — same-tick + scheduled.
        require("config.layout").sync()
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
