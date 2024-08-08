---@class LintConfig
---@field cmd string?
---@field args string[]?
---@field fname boolean?
---@field stdin boolean?
---@field fn function?
---@field parse function
---@field ignore_patterns string|string[]?
---@field ignore_error boolean?
---@field find string|string[]?
---@field env table<string, string>?
---@field timeout integer?

local api = vim.api
local ft_handler = require('guard.filetype')
local util = require('guard.util')
local ns = api.nvim_create_namespace('Guard')
local spawn = require('guard.spawn')
local get_prev_lines = require('guard.util').get_prev_lines
local vd = vim.diagnostic
local M = {}

function M.do_lint(buf)
  buf = buf or api.nvim_get_current_buf()
  ---@type LintConfig[]
  local linters, generic_linters

  local generic_config = ft_handler['*']
  local buf_config = ft_handler[vim.bo[buf].filetype]

  if generic_config and generic_config.linter then
    generic_linters = generic_config.linter
  end

  if not buf_config or not buf_config.linter then
    -- pre: do_lint only triggers inside autocmds, which ensures generic_config and buf_config are not *both* nil
    linters = generic_linters
  else
    -- buf_config exists, we want both
    linters = vim.tbl_map(util.toolcopy, buf_config.linter)
    if generic_linters then
      vim.list_extend(linters, generic_linters)
    end
  end

  -- check run condition
  local fname, startpath, root_dir, cwd = util.buf_get_info(buf)
  linters = vim.tbl_filter(function(config)
    return util.should_run(config, buf, startpath, root_dir)
  end, linters)

  local prev_lines = get_prev_lines(buf, 0, -1)
  vd.reset(ns, buf)

  coroutine.resume(coroutine.create(function()
    local results = {}

    for _, lint in ipairs(linters) do
      local data
      if lint.cmd then
        lint.cwd = lint.cwd or cwd
        data = spawn.transform(util.get_cmd(lint, fname), lint, prev_lines)
      else
        data = lint.fn(prev_lines)
      end
      if #data > 0 then
        vim.list_extend(results, lint.parse(data, buf))
      end
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) or not results or #results == 0 then
        return
      end
      vd.set(ns, buf, results)
    end)
  end))
end

---@param buf number
---@param lnum_start number
---@param lnum_end number
---@param col_start number
---@param col_end number
---@param message string
---@param severity number
---@param source string
function M.diag_fmt(buf, lnum_start, col_start, message, severity, source, lnum_end, col_end)
  return {
    bufnr = buf,
    col = col_start,
    end_col = col_end or col_start,
    lnum = lnum_start,
    end_lnum = lnum_end or lnum_start,
    message = message or '',
    namespace = ns,
    severity = severity or vim.diagnostic.severity.HINT,
    source = source or 'Guard',
  }
end

local severities = {
  error = 1,
  warning = 2,
  info = 3,
  style = 4,
}
M.severities = severities

local from_opts = {
  offset = 1,
  source = nil,
  severities = severities,
}

local regex_opts = {
  regex = nil,
  groups = { 'lnum', 'col', 'severity', 'code', 'message' },
}

local json_opts = {
  get_diagnostics = function(...)
    return vim.json.decode(...)
  end,
  attributes = {
    lnum = 'line',
    col = 'column',
    message = 'message',
    code = 'code',
    severity = 'severity',
  },
  lines = nil,
}

local function formulate_msg(msg, code)
  return (msg or '') .. (code and ('[%s]'):format(code) or '')
end

local function attr_value(mes, attribute)
  return type(attribute) == 'function' and attribute(mes) or mes[attribute]
end

function M.from_json(opts)
  opts = vim.tbl_deep_extend('force', from_opts, opts or {})
  opts = vim.tbl_deep_extend('force', json_opts, opts)

  return function(result, buf)
    local diags, offences = {}, {}

    if opts.lines then
      -- \r\n for windows compatibility
      vim.tbl_map(function(line)
        local offence = opts.get_diagnostics(line)
        if offence then
          offences[#offences + 1] = offence
        end
      end, vim.split(result, '\r?\n', { trimempty = true }))
    else
      offences = opts.get_diagnostics(result)
    end

    vim.tbl_map(function(mes)
      local attr = opts.attributes
      local message = attr_value(mes, attr.message)
      local code = attr_value(mes, attr.code)
      diags[#diags + 1] = M.diag_fmt(
        buf,
        tonumber(attr_value(mes, attr.lnum)) - opts.offset,
        tonumber(attr_value(mes, attr.col)) - opts.offset,
        formulate_msg(message, code),
        opts.severities[attr_value(mes, attr.severity)],
        opts.source,
        tonumber(attr_value(mes, attr.lnum_end or attr.lnum)) - opts.offset,
        tonumber(attr_value(mes, attr.col_end or attr.lnum)) - opts.offset
      )
    end, offences or {})

    return diags
  end
end

function M.from_regex(opts)
  opts = vim.tbl_deep_extend('force', from_opts, opts or {})
  opts = vim.tbl_deep_extend('force', regex_opts, opts)

  return function(result, buf)
    local diags, offences = {}, {}
    -- \r\n for windows compatibility
    local lines = vim.split(result, '\r?\n', { trimempty = true })

    for _, line in ipairs(lines) do
      local offence = {}

      local matches = { line:match(opts.regex) }

      -- regex matched
      if #matches == #opts.groups then
        for i = 1, #opts.groups do
          offence[opts.groups[i]] = matches[i]
        end

        offences[#offences + 1] = offence
      end
    end

    vim.tbl_map(function(mes)
      diags[#diags + 1] = M.diag_fmt(
        buf,
        tonumber(mes.lnum) - opts.offset,
        tonumber(mes.col) - opts.offset,
        formulate_msg(mes.message, mes.code),
        opts.severities[mes.severity],
        opts.source,
        tonumber(mes.lnum_end or mes.lnum) - opts.offset,
        tonumber(mes.col_end or mes.col) - opts.offset
      )
    end, offences)

    return diags
  end
end

return M
