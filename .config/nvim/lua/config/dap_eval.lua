-- A debug "Evaluate Expression" pane, à la PyCharm. It's a prompt buffer
-- registered as a tab in the shared bottom slot (see config.term_tabs): type
-- an expression inline after the `eval ▶ ` prompt and press <CR>; it's
-- evaluated against the active dap session's current frame and the result is
-- appended above the prompt as history.

local M = {}

local buf = nil

local function append(lines)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  -- Insert above the trailing prompt line.
  local n = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, n - 1, n - 1, false, lines)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == buf then
      pcall(vim.api.nvim_win_set_cursor, w, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end
end

function M.eval(expr)
  expr = vim.trim(expr or "")
  if expr == "" then return end
  local session = require("dap").session()
  if not session then
    append({ "▶ " .. expr, "    (no active debug session)" })
    return
  end
  local frame = session.current_frame
  session:request("evaluate", {
    expression = expr,
    frameId = frame and frame.id,
    context = "repl",
  }, function(err, body)
    vim.schedule(function()
      local result = err and ("error: " .. (err.message or vim.inspect(err)))
        or (body and body.result) or "nil"
      local out = { "▶ " .. expr }
      for _, l in ipairs(vim.split("    = " .. result, "\n", { plain = true })) do
        out[#out + 1] = l
      end
      append(out)
    end)
  end)
end

local function ensure_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then return buf end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].filetype = "dap-eval"
  pcall(vim.api.nvim_buf_set_name, buf, "DAP Evaluate")
  vim.fn.prompt_setprompt(buf, "eval ▶ ")
  vim.fn.prompt_setcallback(buf, function(text) M.eval(text) end)
  -- Header above the prompt line.
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, {
    "  Evaluate Expression — type an expression and press <CR>",
  })
  return buf
end

function M.buf()
  return ensure_buf()
end

-- Focus the eval pane and drop into insert at the prompt for immediate typing.
function M.focus_insert()
  ensure_buf()
  vim.schedule(function()
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        vim.api.nvim_set_current_win(w)
        vim.cmd("startinsert")
        return
      end
    end
  end)
end

return M
