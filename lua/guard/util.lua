---@diagnostic disable-next-line: deprecated
local get_clients = vim.version().minor >= 10 and vim.lsp.get_clients or vim.lsp.get_active_clients
local api = vim.api
local util = {}

function util.get_prev_lines(bufnr, srow, erow)
  local tbl = api.nvim_buf_get_lines(bufnr, srow, erow, false)
  local res = {}
  for _, text in ipairs(tbl) do
    res[#res + 1] = text .. '\n'
  end
  return res
end

function util.get_lsp_root(buf)
  buf = buf or api.nvim_get_current_buf()
  local clients = get_clients({ bufnr = buf })
  if #clients == 0 then
    return
  end
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end
end

function util.as_table(t)
  return vim.tbl_islist(t) and t or { t }
end

-- TODO: Use `vim.region()` instead ?
---@param bufnr integer
---@param mode "v"|"V"
---@return table {start={row,col}, end={row,col}} using (1, 0) indexing
function util.range_from_selection(bufnr, mode)
  -- [bufnum, lnum, col, off]; both row and column 1-indexed
  local start = vim.fn.getpos('v')
  local end_ = vim.fn.getpos('.')
  local start_row = start[2]
  local start_col = start[3]
  local end_row = end_[2]
  local end_col = end_[3]

  -- A user can start visual selection at the end and move backwards
  -- Normalize the range to start < end
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

function util.get_clients(bufnr, method)
  if vim.version().minor >= 10 then
    return vim.lsp.get_clients({ bufnr = bufnr, method = method })
  end
  local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
  return vim.tbl_filter(function(client)
    return client.supports_method(method)
  end, clients)
end

function util.doau(pattern, data)
  api.nvim_exec_autocmds('User', {
    pattern = pattern,
    data = data,
  })
end

return util
