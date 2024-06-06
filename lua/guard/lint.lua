local api = vim.api
---@diagnostic disable-next-line: deprecated
local uv = vim.version().minor >= 10 and vim.uv or vim.loop
local ft_handler = require('guard.filetype')
local spawn = require('guard.spawn').try_spawn
local ns = api.nvim_create_namespace('Guard')
local get_prev_lines = require('guard.util').get_prev_lines
local vd = vim.diagnostic
local M = {}

function M.do_lint(buf)
  buf = buf or api.nvim_get_current_buf()
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
    linters = vim.deepcopy(buf_config.linter)
    if generic_linters then
      vim.list_extend(linters, generic_linters)
    end
  end
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  local prev_lines = get_prev_lines(buf, 0, -1)
  vd.reset(ns, buf)

  coroutine.resume(coroutine.create(function()
    local results = {}

    for _, lint in ipairs(linters) do
      lint = vim.deepcopy(lint)
      lint.args = lint.args or {}
      lint.args[#lint.args + 1] = fname
      lint.lines = prev_lines
      local data = spawn(lint)
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

function M.diag_fmt(buf, lnum, col, message, severity, source)
  return {
    bufnr = buf,
    col = col,
    end_col = col,
    end_lnum = lnum,
    lnum = lnum,
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

function M.from_json(opts)
  opts = vim.tbl_deep_extend('force', from_opts, opts or {})
  opts = vim.tbl_deep_extend('force', json_opts, opts)

  return function(result, buf)
    local diags, offences = {}, {}

    if opts.lines then
      -- \r\n for windows compatibility
      vim.tbl_map(function(line)
        offences[#offences + 1] = opts.get_diagnostics(line)
      end, vim.split(result, '\r?\n', { trimempty = true }))
    else
      offences = opts.get_diagnostics(result)
    end

    vim.tbl_map(function(mes)
      local function attr_value(attribute)
        return type(attribute) == 'function' and attribute(mes) or mes[attribute]
      end
      local message, code = attr_value(opts.attributes.message), attr_value(opts.attributes.code)
      diags[#diags + 1] = M.diag_fmt(
        buf,
        tonumber(attr_value(opts.attributes.lnum)) - opts.offset,
        tonumber(attr_value(opts.attributes.col)) - opts.offset,
        formulate_msg(message, code),
        opts.severities[attr_value(opts.attributes.severity)],
        opts.source
      )
    end, offences or {})

    return diags
  end
end

local regex_opts = {
  regex = nil,
  groups = { 'lnum', 'col', 'severity', 'code', 'message' },
}

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
        opts.source
      )
    end, offences)

    return diags
  end
end

return M
