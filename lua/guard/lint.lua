local async = require('guard._async')
local api = vim.api
local util = require('guard.util')
local vd = vim.diagnostic
local ft = require('guard.filetype')

local M = {}
local ns = api.nvim_create_namespace('Guard')
local custom_ns = {}

---Execute command with stdin for linting
---@async
---@param cmd string[]
---@param cwd string
---@param config {env: table?, timeout: integer?}
---@param input string|string[]
---@return string output
---@return {code: integer, stderr: string, cmd: string}? error
local function exec_linter(cmd, cwd, config, input)
  local result = async.await(1, function(callback)
    local handle = vim.system(cmd, {
      stdin = true,
      cwd = cwd,
      env = config.env,
      timeout = config.timeout,
    }, callback)
    if type(input) == 'table' then
      input = table.concat(input, '\n')
    end
    handle:write(input)
    handle:write(nil)
  end)

  if result.code ~= 0 and #result.stderr > 0 then
    return '', {
      code = result.code,
      stderr = result.stderr,
      cmd = cmd[1],
    }
  end

  return result.stdout, nil
end

---@param buf number?
function M.do_lint(buf)
  buf = buf or api.nvim_get_current_buf()

  local linters = util.eval(
    vim.tbl_map(
      util.toolcopy,
      (vim.tbl_get(ft, vim.bo[buf].filetype, 'linter') or vim.tbl_get(ft, '*', 'linter'))
    )
  )

  linters = vim.tbl_filter(function(config)
    return util.should_run(config, buf)
  end, linters)

  async.run(function()
    vd.reset(ns, buf)
    for _, linter in ipairs(linters) do
      M.do_lint_single(buf, linter)
    end
  end)
end

---@param buf number
---@param config LintConfig
function M.do_lint_single(buf, config)
  local lint = util.eval1(config)
  local custom = config.events ~= nil

  local fname, cwd = util.buf_get_info(buf)
  if not util.should_run(lint, buf) then
    return
  end

  local prev_lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  if custom and not custom_ns[config] then
    custom_ns[config] = api.nvim_create_namespace(tostring(config))
  end
  local cns = custom and custom_ns[config] or ns

  if custom then
    vd.reset(cns, buf)
  end

  local results = {}
  local data = ''

  if lint.cmd then
    async.run(function()
      local out, err = exec_linter(util.get_cmd(lint, fname, buf), cwd, lint, prev_lines)

      if err then
        vim.notify(
          '[Guard]: ' .. ('%s exited with code %d\n%s'):format(err.cmd, err.code, err.stderr),
          vim.log.levels.WARN
        )
        data = ''
      else
        data = out
      end

      if #data > 0 then
        results = lint.parse(data, buf, fname, cwd)
      end

      vim.schedule(function()
        if api.nvim_buf_is_valid(buf) and #results ~= 0 then
          if not custom then
            vim.list_extend(results, vd.get(buf))
          end
          vd.set(cns, buf, results)
        end
      end)
    end)
  else
    data = lint.fn(prev_lines, fname, cwd)
    if #data > 0 then
      results = lint.parse(data, buf, fname, cwd)
    end

    vim.schedule(function()
      if api.nvim_buf_is_valid(buf) and #results ~= 0 then
        if not custom then
          vim.list_extend(results, vd.get(buf))
        end
        vd.set(cns, buf, results)
      end
    end)
  end
end

---@param buf number
---@param lnum_start number?
---@param lnum_end number?
---@param col_start number?
---@param col_end number?
---@param message string?
---@param severity number?
---@param source string?
---@param code string?
function M.diag_fmt(buf, lnum_start, col_start, message, severity, source, lnum_end, col_end, code)
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
    code = code,
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

local function attr_value(mes, attribute)
  return type(attribute) == 'function' and attribute(mes) or mes[attribute]
end

---@param nr any?
---@param off number
local function normalize(nr, off)
  if not nr or nr == '' then
    return 0
  else
    return tonumber(nr) - off
  end
end

local function json_get_offset(mes, attr, off)
  return normalize(attr_value(mes, attr), off)
end

function M.from_json(opts)
  opts = vim.tbl_deep_extend('force', from_opts, opts or {})
  opts = vim.tbl_deep_extend('force', json_opts, opts)

  return function(result, buf)
    local diags, offences = {}, {}

    if opts.lines then
      vim.tbl_map(function(line)
        local offence = opts.get_diagnostics(line)
        if offence then
          table.insert(offences, offence)
        end
      end, vim.split(result, '\r?\n', { trimempty = true }))
    else
      offences = opts.get_diagnostics(result)
    end

    local attr = opts.attributes
    local off = opts.offset
    vim.tbl_map(function(mes)
      local message = attr_value(mes, attr.message)
      local code = attr_value(mes, attr.code)
      table.insert(
        diags,
        M.diag_fmt(
          buf,
          json_get_offset(mes, attr.lnum, off),
          json_get_offset(mes, attr.col, off),
          message,
          opts.severities[attr_value(mes, attr.severity)],
          opts.source,
          json_get_offset(mes, attr.lnum_end or attr.lnum, off),
          json_get_offset(mes, attr.col_end or attr.col, off),
          code
        )
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
    local lines = vim.split(result, '\r?\n', { trimempty = true })

    for _, line in ipairs(lines) do
      local offence = {}

      local matches = { line:match(opts.regex) }

      if #matches == #opts.groups then
        for i = 1, #opts.groups do
          offence[opts.groups[i]] = matches[i]
        end

        table.insert(offences, offence)
      end
    end

    local off = opts.offset
    vim.tbl_map(function(mes)
      table.insert(
        diags,
        M.diag_fmt(
          buf,
          normalize(mes.lnum, off),
          normalize(mes.col, off),
          mes.message,
          opts.severities[mes.severity],
          opts.source,
          normalize(mes.lnum_end or mes.lnum, off),
          normalize(mes.col_end or mes.lnum, off),
          mes.code
        )
      )
    end, offences)

    return diags
  end
end

return M
