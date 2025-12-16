local async = require('guard._async')
local M = {}
local api = vim.api
local apply = vim.lsp.util.apply_text_edits

---@param buf number
---@param range table?
---@param acc string
---@return string
function M.format(buf, range, acc)
  local clients = vim.lsp.get_clients({ bufnr = buf, method = 'textDocument/formatting' })
  if #clients == 0 then
    return acc
  end

  -- use a temporary buffer to apply edits
  local scratch = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(acc, '\r?\n'))
  local line_offset = range and range.start[1] - 1 or 0

  local c = clients[1]
  return async.await(1, function(callback)
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.lsp.util.apply_text_edits = function(...)
      local text_edits, bufnr, offset_encoding = ...
      if bufnr == buf then
        -- we apply it to our scratch buffer
        vim.tbl_map(function(edit)
          edit.range.start.line = edit.range.start.line - line_offset
          edit.range['end'].line = edit.range['end'].line - line_offset
        end, text_edits)
        apply(text_edits, scratch, offset_encoding)
        vim.lsp.util.apply_text_edits = apply
        local lines = api.nvim_buf_get_lines(scratch, 0, -1, false)
        api.nvim_command('silent! bwipe! ' .. scratch)
        callback(table.concat(lines, '\n'))
      else
        apply(...)
      end
    end

    vim.lsp.buf.format({
      bufnr = buf,
      range = range,
      async = true,
      id = c.id,
    })
  end)
end

return M
