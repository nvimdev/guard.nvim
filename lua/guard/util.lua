local api = vim.api
local M = {}

function M.get_prev_lines(bufnr, srow, erow)
  local tbl = api.nvim_buf_get_lines(bufnr, srow, erow, false)
  local res = {}
  for _, text in ipairs(tbl) do
    res[#res + 1] = text .. '\n'
  end
  return res
end

function M.get_lsp_root(buf)
  buf = buf or api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf })
  if #clients == 0 then
    return
  end
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end
end

function M.as_table(t)
  return vim.islist(t) and t or { t }
end

---@source runtime/lua/vim/lsp/buf.lua
---@param bufnr integer
---@param mode "v"|"V"
---@return table {start={row,col}, end={row,col}} using (1, 0) indexing
function M.range_from_selection(bufnr, mode)
  local start = vim.fn.getpos('v')
  local end_ = vim.fn.getpos('.')
  local start_row = start[2]
  local start_col = start[3]
  local end_row = end_[2]
  local end_col = end_[3]
  if start_row == end_row and end_col < start_col then
    end_col, start_col = start_col, end_col
  elseif end_row < start_row then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end
  if mode == 'V' then
    start_col = 1
    local lines = api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)
    end_col = #lines[1]
  end
  return {
    ['start'] = { start_row, start_col - 1 },
    ['end'] = { end_row, end_col - 1 },
  }
end

function M.doau(pattern, data)
  api.nvim_exec_autocmds('User', {
    pattern = pattern,
    data = data,
  })
end

function M.get_cmd(config, fname)
  local cmd = config.args and vim.deepcopy(config.args) or {}
  table.insert(cmd, 1, config.cmd)
  if config.fname then
    table.insert(cmd, fname)
  end
  return cmd
end

return M
