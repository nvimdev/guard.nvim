local M = {}
local api = vim.api
local scratch = api.nvim_create_buf(false, true)

function M.format(buf, range, acc)
  local co = assert(coroutine.running())
  local clients = vim.lsp.get_clients({ bufnr = buf, method = 'textDocument/formatting' })
  if #clients == 0 then
    return acc
  end

  local apply = vim.lsp.util.apply_text_edits
  local n_edits = #clients
  api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(acc, '\r?\n'))
  local line_offset = range and range.start[1] - 1 or 0

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.apply_text_edits = function(text_edits, bufnr, offset_encoding)
    if bufnr ~= buf then
      apply(text_edits, bufnr, offset_encoding)
    end

    -- we apply it to our scratch buffer
    n_edits = n_edits - 1
    vim.print(line_offset)
    vim.print(text_edits)
    vim.tbl_map(function(edit)
      edit.range.start.line = edit.range.start.line - line_offset
      edit.range['end'].line = edit.range['end'].line - line_offset
    end, text_edits)
    vim.print(text_edits)
    apply(text_edits, scratch, offset_encoding)
    if n_edits == 0 then
      vim.lsp.util.apply_text_edits = apply
      coroutine.resume(co, table.concat(api.nvim_buf_get_lines(scratch, 0, -1, false), '\n'))
    end
  end

  vim.lsp.buf.format({
    bufnr = buf,
    range = range,
    async = true,
  })

  return coroutine.yield()
end

return M
