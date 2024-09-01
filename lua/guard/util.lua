local api = vim.api
local iter = vim.iter
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

local ffi = require('ffi')
ffi.cdef([[
bool os_can_exe(const char *name, char **abspath, bool use_path)
]])

---@param exe string
---@return string
local function exepath_ffi(exe)
  local charpp = ffi.new('char*[1]')
  assert(ffi.C.os_can_exe(exe, charpp, true))
  return ffi.string(charpp[0])
end

---@param config FmtConfig|LintConfig
---@param fname string
---@return string[]
function M.get_cmd(config, fname)
  local cmd = config.args and vim.deepcopy(config.args) or {}
  if config.fname then
    table.insert(cmd, fname)
  end
  table.insert(cmd, 1, exepath_ffi(config.cmd))
  return cmd
end

---@param startpath string
---@param patterns string[]|string?
---@param root_dir string?
---@return boolean
local function find(startpath, patterns, root_dir)
  return iter(M.as_table(patterns)):any(function(pattern)
    return #vim.fs.find(pattern, {
      upward = true,
      stop = root_dir and vim.fn.fnamemodify(root_dir, ':h') or vim.env.HOME,
      path = startpath,
    }) > 0
  end)
end

---@param buf number
---@param patterns string[]|string?
---@return boolean
local function ignored(buf, patterns)
  local fname = api.nvim_buf_get_name(buf)
  if #fname == 0 then
    return false
  end

  return iter(M.as_table(patterns)):any(function(pattern)
    return fname:find(pattern) ~= nil
  end)
end

---@param config FmtConfig|LintConfig
---@param buf integer
---@param startpath string
---@param root_dir string?
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

---@return string, string, string?, string
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

---@param msg string
function M.report_error(msg)
  vim.notify('[Guard]: ' .. msg, vim.log.levels.WARN)
end

---@param opt string
function M.getopt(opt)
  local default = {
    fmt_on_save = true,
    lsp_as_default_formatter = false,
    save_on_fmt = true,
  }
  if
    not vim.g.guard_config
    or type(vim.g.guard_config) ~= 'table'
    or vim.g.guard_config[opt] == nil
  then
    return default[opt]
  end
  return vim.g.guard_config[opt]
end

function M.open_info_win()
  local height, width = vim.o.lines, vim.o.columns
  local pad_top = math.ceil(height * 0.15)
  local pad_bot = math.ceil(height * 0.2)
  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = pad_top,
    col = math.floor(width * 0.2),
    height = height - pad_top - pad_bot,
    width = math.ceil(width * 0.6),
    border = 'single',
  })
  vim.bo.ft = 'markdown'
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  api.nvim_set_option_value('conceallevel', 3, { win = win })
  api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '<cmd>quit!<cr>', {})
  api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>quit!<cr>', {})
end

return M
