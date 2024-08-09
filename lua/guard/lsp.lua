local M = {}
local api = vim.api
local apply = vim.lsp.util.apply_text_edits

---@param buf number
---@param range table
---@param acc string
---@return string
function M.format(buf, range, acc)
  local co = assert(coroutine.running())
  local clients = vim.lsp.get_clients({ bufnr = buf, method = 'textDocument/formatting' })
  if #clients == 0 then
    return acc
  end

  -- use a temporary buffer to apply edits
  local scratch = api.nvim_create_buf(false, true)
  local n_edits = #clients
  api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(acc, '\r?\n'))
  local line_offset = range and range.start[1] - 1 or 0

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.apply_text_edits = function(text_edits, _, offset_encoding)
    -- the target buffer must be buf, we apply it to our scratch buffer
    n_edits = n_edits - 1
    vim.tbl_map(function(edit)
      edit.range.start.line = edit.range.start.line - line_offset
      edit.range['end'].line = edit.range['end'].line - line_offset
    end, text_edits)
    apply(text_edits, scratch, offset_encoding)
    if n_edits == 0 then
      vim.lsp.util.apply_text_edits = apply
      local lines = api.nvim_buf_get_lines(scratch, 0, -1, false)
      api.nvim_command('silent! bwipe! ' .. scratch)
      coroutine.resume(co, table.concat(lines, '\n'))
    end
  end

  vim.lsp.buf.format({
    bufnr = buf,
    range = range,
    async = true,
  })

  return (coroutine.yield())
end

return M
