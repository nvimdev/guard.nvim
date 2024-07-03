local api = vim.api
local M = {}

---@param bufnr number
---@param srow number
---@param erow number
---@return string[]
function M.get_prev_lines(bufnr, srow, erow)
  local tbl = api.nvim_buf_get_lines(bufnr, srow, erow, false)
  local res = {}
  for _, text in ipairs(tbl) do
    res[#res + 1] = text .. '\n'
  end
  return res
end

---@return string?
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

---@param config FmtConfig|LintConfig
---@param fname string
---@return string[]
function M.get_cmd(config, fname)
  local cmd = config.args and vim.deepcopy(config.args) or {}
  table.insert(cmd, 1, vim.fn.exepath(config.cmd))
  if config.fname then
    table.insert(cmd, fname)
  end
  return cmd
end

---@param startpath string
---@param patterns string[]|string?
---@param root_dir string
---@return boolean
local function find(startpath, patterns, root_dir)
  patterns = M.as_table(patterns)
  for _, pattern in ipairs(patterns) do
    if
      #vim.fs.find(pattern, {
        upward = true,
        stop = root_dir and vim.fn.fnamemodify(root_dir, ':h') or vim.env.HOME,
        path = startpath,
      }) > 0
    then
      return true
    end
  end
  return false
end

---@param buf number
---@param patterns string[]
---@return boolean
local function ignored(buf, patterns)
  local fname = api.nvim_buf_get_name(buf)
  if #fname == 0 then
    return false
  end

  for _, pattern in pairs(M.as_table(patterns)) do
    if fname:find(pattern) then
      return true
    end
  end
  return false
end

---@param config FmtConfig|LintConfig
---@param buf integer
---@param startpath string
---@param root_dir string
---@return boolean
function M.should_run(config, buf, startpath, root_dir)
  if config.ignore_patterns and ignored(buf, config.ignore_patterns) then
    return false
  elseif config.ignore_error and #vim.diagnostic.get(buf, { severity = 1 }) ~= 0 then
    return false
  elseif config.find and not find(startpath, config.find, root_dir) then
    return false
  end
  return true
end

---@return string, string, string, string
function M.buf_get_info(buf)
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  local startpath = vim.fn.fnamemodify(fname, ':p:h')
  local root_dir = M.get_lsp_root()
  ---@diagnostic disable-next-line: undefined-field
  local cwd = root_dir or vim.uv.cwd()
  ---@diagnostic disable-next-line: return-type-mismatch
  return fname, startpath, root_dir, cwd
end

---@param c (FmtConfig|LintConfig)?
---@return (FmtConfig|LintConfig)?
function M.toolcopy(c)
  if not c or vim.tbl_isempty(c) then
    return nil
  end
  return {
    cmd = c.cmd,
    args = c.args,
    fname = c.fname,
    stdin = c.stdin,
    fn = c.fn,
    ignore_patterns = c.ignore_patterns,
    ignore_error = c.ignore_error,
    find = c.find,
    env = c.env,
    timeout = c.timeout,
    parse = c.parse,
  }
end

function M.report_error(msg)
  vim.notify('[Guard]: ' .. msg, vim.log.levels.WARN)
end

return M
