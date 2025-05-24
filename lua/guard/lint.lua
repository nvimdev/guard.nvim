local lib = require('guard.lib')
local Result = lib.Result
local Async = lib.Async
local util = require('guard.util')
local filetype = require('guard.filetype')
local api = vim.api
local vd = vim.diagnostic

local M = {}

local ns = api.nvim_create_namespace('Guard')
local custom_ns = {}

-- Lint context for managing lint session
local LintContext = {}
LintContext.__index = LintContext

function LintContext.new(bufnr)
  return setmetatable({
    bufnr = bufnr,
    ft = vim.bo[bufnr].filetype,
    ctx = Async.context(),
  }, LintContext)
end

function LintContext:cancel()
  self.ctx:cancel()
end

-- Linter runners
local Linters = {}

-- Run a linter function
function Linters.run_function(lines, config)
  return Async.try(function()
    return config.fn(lines)
  end)
end

-- Run a linter command
function Linters.run_command(config, lines, fname, cwd)
  local cmd = util.get_cmd(config, fname)

  return Async.system(cmd, {
    stdin = config.stdin and table.concat(lines, '\n') or nil,
    cwd = cwd,
    env = config.env,
    timeout = config.timeout,
  })
end

-- Get or create namespace for custom event linters
local function get_namespace(config)
  if config.events and not custom_ns[config] then
    custom_ns[config] = api.nvim_create_namespace(tostring(config))
  end
  return config.events and custom_ns[config] or ns
end

-- Parse linter output into diagnostics
local function parse_diagnostics(config, output, bufnr)
  if not output or output == '' then
    return Result.ok({})
  end

  return Async.try(function()
    return config.parse(output, bufnr)
  end)
end

-- Apply diagnostics to buffer
local function apply_diagnostics(ctx, namespace, diagnostics, is_custom)
  vim.schedule(function()
    if not api.nvim_buf_is_valid(ctx.bufnr) then
      return
    end

    if is_custom then
      -- Custom linters clear their own namespace
      vd.reset(namespace, ctx.bufnr)
      vd.set(namespace, ctx.bufnr, diagnostics)
    else
      -- Default linters merge with existing diagnostics
      local existing = vd.get(ctx.bufnr)
      vim.list_extend(diagnostics, existing)
      vd.set(namespace, ctx.bufnr, diagnostics)
    end
  end)
end

-- Run a single linter
local run_single_linter = Async.callback(function(ctx, config, lines, fname, cwd)
  -- Evaluate config if it's a function
  local lint_config = util.eval1(config)

  -- Check if should run
  if not util.should_run(lint_config, ctx.bufnr) then
    return Result.ok({ diagnostics = {}, skipped = true })
  end

  -- Get namespace
  local namespace = get_namespace(config)
  local is_custom = config.events ~= nil

  -- Clear custom namespace diagnostics
  if is_custom then
    vd.reset(namespace, ctx.bufnr)
  end

  -- Run linter
  local output_result
  if lint_config.fn then
    output_result = Linters.run_function(lines, lint_config)
  else
    output_result = Async.await(ctx.ctx:run(Linters.run_command(lint_config, lines, fname, cwd)))
  end

  -- Handle errors
  if output_result:is_err() then
    local err = output_result.error
    if err.type == Async.Error.COMMAND_FAILED then
      local details = err.details
      vim.notify(
        string.format(
          '[Guard]: %s exited with code %d\n%s',
          details.cmd,
          details.code,
          details.stderr or ''
        ),
        vim.log.levels.WARN
      )
      return Result.ok({ diagnostics = {}, error = true })
    end
    return output_result
  end

  -- Get output
  local output = lint_config.cmd and output_result.value.stdout or output_result.value

  -- Parse diagnostics
  local parse_result = parse_diagnostics(lint_config, output, ctx.bufnr)
  if parse_result:is_err() then
    vim.notify(
      string.format('[Guard]: Failed to parse linter output: %s', parse_result.error),
      vim.log.levels.WARN
    )
    return Result.ok({ diagnostics = {}, parse_error = true })
  end

  local diagnostics = parse_result.value or {}

  -- Apply diagnostics
  apply_diagnostics(ctx, namespace, diagnostics, is_custom)

  return Result.ok({
    diagnostics = diagnostics,
    namespace = namespace,
    is_custom = is_custom,
  })
end)

-- Main lint function
function M.do_lint(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  -- Get linter configurations
  local ft = vim.bo[bufnr].filetype
  local ft_config = filetype[ft] or filetype['*']

  if not ft_config or not ft_config.linter or #ft_config.linter == 0 then
    return
  end

  -- Create lint context
  local ctx = LintContext.new(bufnr)

  -- Get buffer info
  local fname, cwd = util.buf_get_info(bufnr)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Evaluate and filter linters
  local linters = util.eval(vim.tbl_map(util.toolcopy, ft_config.linter))

  linters = vim.tbl_filter(function(config)
    return util.should_run(config, bufnr)
  end, linters)

  if #linters == 0 then
    return
  end

  -- Clear default namespace before running linters
  vd.reset(ns, bufnr)

  -- Run all linters in parallel
  local promises = vim.tbl_map(function(linter)
    return run_single_linter(ctx, linter, lines, fname, cwd)
  end, linters)

  Async.all_settled(promises)(function(results)
    -- Log any errors but don't fail the whole operation
    if vim.g.guard_debug then
      vim.iter(results):each(function(result)
        if result:is_err() then
          vim.notify('[Guard Debug] Linter failed: ' .. vim.inspect(result.error))
        end
      end)
    end
  end)
end

-- Run a single linter (public API for custom events)
function M.do_lint_single(bufnr, config)
  bufnr = bufnr or api.nvim_get_current_buf()

  local ctx = LintContext.new(bufnr)
  local fname, cwd = util.buf_get_info(bufnr)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

  run_single_linter(ctx, config, lines, fname, cwd)(function(result)
    if result:is_err() then
      vim.notify('[Guard]: Linter failed: ' .. result.error, vim.log.levels.ERROR)
    end
  end)
end

-- Diagnostic formatting helper
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

-- Severity levels
M.severities = {
  error = 1, -- vim.diagnostic.severity.ERROR
  warning = 2, -- vim.diagnostic.severity.WARN
  info = 3, -- vim.diagnostic.severity.INFO
  style = 4, -- vim.diagnostic.severity.HINT
}

-- Parser factories
local Parsers = {}

-- Common parser options
local default_opts = {
  offset = 1,
  source = nil,
  severities = M.severities,
}

-- JSON parser factory
function Parsers.json(opts)
  opts = vim.tbl_deep_extend('force', default_opts, opts or {})

  -- Default JSON options
  local json_defaults = {
    get_diagnostics = vim.json.decode,
    attributes = {
      lnum = 'line',
      col = 'column',
      message = 'message',
      code = 'code',
      severity = 'severity',
    },
    lines = false,
  }

  opts = vim.tbl_deep_extend('force', json_defaults, opts)

  return function(output, bufnr)
    local diagnostics = {}
    local offences = {}

    -- Parse output
    local ok, parsed = pcall(function()
      if opts.lines then
        -- Parse each line separately
        for line in vim.gsplit(output, '\r?\n', { trimempty = true }) do
          local offence = opts.get_diagnostics(line)
          if offence then
            table.insert(offences, offence)
          end
        end
      else
        -- Parse whole output
        offences = opts.get_diagnostics(output) or {}
      end
    end)

    if not ok then
      return {}
    end

    -- Convert to diagnostics
    local attr = opts.attributes
    local off = opts.offset

    for _, offence in ipairs(offences) do
      local function get_value(key)
        local attribute = attr[key]
        if type(attribute) == 'function' then
          return attribute(offence)
        else
          return offence[attribute]
        end
      end

      local function normalize(value)
        if not value or value == '' then
          return 0
        end
        return tonumber(value) - off
      end

      local message = get_value('message')
      local code = get_value('code')

      table.insert(
        diagnostics,
        M.diag_fmt(
          bufnr,
          normalize(get_value('lnum')),
          normalize(get_value('col')),
          message .. (code and (' [' .. code .. ']') or ''),
          opts.severities[get_value('severity')],
          opts.source,
          normalize(get_value('lnum_end') or get_value('lnum')),
          normalize(get_value('col_end') or get_value('col'))
        )
      )
    end

    return diagnostics
  end
end

-- Regex parser factory
function Parsers.regex(opts)
  opts = vim.tbl_deep_extend('force', default_opts, opts or {})

  -- Default regex options
  local regex_defaults = {
    regex = nil,
    groups = { 'lnum', 'col', 'severity', 'code', 'message' },
  }

  opts = vim.tbl_deep_extend('force', regex_defaults, opts)

  if not opts.regex then
    error('regex parser requires a regex pattern')
  end

  return function(output, bufnr)
    local diagnostics = {}
    local off = opts.offset

    -- Parse each line
    for line in vim.gsplit(output, '\r?\n', { trimempty = true }) do
      local matches = { line:match(opts.regex) }

      if #matches == #opts.groups then
        local offence = {}
        for i = 1, #opts.groups do
          offence[opts.groups[i]] = matches[i]
        end

        local function normalize(value)
          if not value or value == '' then
            return 0
          end
          return tonumber(value) - off
        end

        local message = offence.message or ''
        local code = offence.code

        table.insert(
          diagnostics,
          M.diag_fmt(
            bufnr,
            normalize(offence.lnum),
            normalize(offence.col),
            message .. (code and (' [' .. code .. ']') or ''),
            opts.severities[offence.severity],
            opts.source,
            normalize(offence.lnum_end or offence.lnum),
            normalize(offence.col_end or offence.col)
          )
        )
      end
    end

    return diagnostics
  end
end

M.from_json = Parsers.json
M.from_regex = Parsers.regex

return M
