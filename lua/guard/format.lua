local lib = require('guard.lib')
local Result = lib.Result
local Async = lib.Async
local util = require('guard.util')
local filetype = require('guard.filetype')
local api = vim.api

local M = {}

-- Buffer state management
local BufferState = {}
BufferState.__index = BufferState

function BufferState.new(bufnr)
  return setmetatable({
    bufnr = bufnr,
    views = {},
    changedtick = -1,
  }, BufferState)
end

function BufferState:save_views()
  self.views = {}
  for _, win in ipairs(vim.fn.win_findbuf(self.bufnr)) do
    self.views[win] = api.nvim_win_call(win, vim.fn.winsaveview)
  end
  return self
end

function BufferState:restore_views()
  for win, view in pairs(self.views) do
    if api.nvim_win_is_valid(win) then
      api.nvim_win_call(win, function()
        vim.fn.winrestview(view)
      end)
    end
  end
  return self
end

function BufferState:save_changedtick()
  self.changedtick = api.nvim_buf_get_changedtick(self.bufnr)
  return self
end

function BufferState:is_modified()
  return api.nvim_buf_get_changedtick(self.bufnr) ~= self.changedtick
end

function BufferState:is_valid()
  return api.nvim_buf_is_valid(self.bufnr)
end

-- Format context to track the formatting session
local FormatContext = {}
FormatContext.__index = FormatContext

function FormatContext.new(bufnr, range, mode)
  local self = setmetatable({
    bufnr = bufnr,
    range = range,
    mode = mode,
    state = BufferState.new(bufnr),
    ctx = Async.context(),
  }, FormatContext)

  -- Calculate row boundaries
  if range then
    self.start_row = range.start[1] - 1
    self.end_row = range['end'][1]
  else
    self.start_row = 0
    self.end_row = -1
  end

  -- Check if we need to preserve indent
  self.preserve_indent = mode == 'V' and range and vim.fn.indent(self.start_row + 1) or nil

  return self
end

function FormatContext:get_lines()
  return api.nvim_buf_get_lines(self.bufnr, self.start_row, self.end_row, false)
end

function FormatContext:get_text()
  return table.concat(self:get_lines(), '\n')
end

function FormatContext:cancel()
  self.ctx:cancel()
end

-- Formatter types and runners
local Formatters = {}

-- Formatter categories:
-- 1. Pure formatters: Can process text without side effects
--    - Functions: config.fn
--    - Commands with stdin/stdout: config.cmd + config.stdin
-- 2. Impure formatters: Modify files directly
--    - Commands without stdin: config.cmd + !config.stdin
--    These MUST run last to avoid conflicts

-- Run a formatter function (pure)
function Formatters.run_function(bufnr, range, config, input)
  return Async.try(function()
    return config.fn(bufnr, range, input)
  end)
end

-- Run a command formatter
function Formatters.run_command(config, input, fname, cwd)
  local cmd = util.get_cmd(config, fname)

  return Async.system(cmd, {
    stdin = input, -- nil for impure formatters
    cwd = cwd,
    env = config.env,
    timeout = config.timeout,
  })
end

-- Process and categorize formatter configurations
function Formatters.prepare_configs(ft_conf, bufnr)
  local configs = util.eval(ft_conf.formatter)

  -- Filter by run conditions
  configs = vim.tbl_filter(function(config)
    return util.should_run(config, bufnr)
  end, configs)

  -- Check executables
  local errors = {}
  for _, config in ipairs(configs) do
    if config.cmd and vim.fn.executable(config.cmd) ~= 1 then
      table.insert(errors, config.cmd .. ' not executable')
    end
  end

  if #errors > 0 then
    return Result.err(table.concat(errors, '\n'))
  end

  -- Categorize formatters
  -- Pure: process text in memory (functions or stdin/stdout commands)
  -- Impure: modify files directly (commands without stdin)
  local categorized = {
    all = configs,
    pure = {},
    impure = {},
  }

  for _, config in ipairs(configs) do
    if config.fn or (config.cmd and config.stdin) then
      table.insert(categorized.pure, config)
    elseif config.cmd and not config.stdin then
      table.insert(categorized.impure, config)
    end
  end

  return Result.ok(categorized)
end

-- Check if formatters support range formatting
function Formatters.validate_range_support(configs, range)
  if not range then
    return Result.ok(true)
  end

  -- Range formatting requires all formatters to be pure (stdin capable)
  if #configs.impure > 0 then
    local impure_cmds = vim.tbl_map(function(c)
      return c.cmd
    end, configs.impure)
    return Result.err({
      message = 'Cannot apply range formatting',
      details = table.concat(impure_cmds, ', ') .. ' does not support reading from stdin',
    })
  end

  return Result.ok(true)
end

-- Apply formatted text to buffer
local function apply_buffer_changes(ctx, original_text, formatted_text)
  if not formatted_text or #formatted_text == 0 then
    return Result.ok(false)
  end

  -- Split into lines, handling Windows line endings
  local new_lines = vim.split(formatted_text, '\r?\n')
  if new_lines[#new_lines] == '' then
    new_lines[#new_lines] = nil
  end

  local original_lines = vim.split(original_text, '\n')

  -- Check if content actually changed
  if vim.deep_equal(new_lines, original_lines) then
    return Result.ok(false)
  end

  -- Apply changes
  ctx.state:save_views()

  api.nvim_buf_set_lines(ctx.bufnr, ctx.start_row, ctx.end_row, false, new_lines)

  -- Save if configured
  if util.getopt('save_on_fmt') then
    vim.cmd('silent! noautocmd write!')
  end

  -- Restore indent if needed
  if ctx.preserve_indent then
    vim.cmd(('silent %d,%dleft'):format(ctx.start_row + 1, ctx.end_row))
  end

  ctx.state:restore_views()

  return Result.ok(true)
end

-- Send format event
local function send_event(status, data)
  util.doau('GuardFmt', vim.tbl_extend('force', { status = status }, data or {}))
end

-- Format notification
local function notify_error(msg)
  send_event('failed', { msg = msg })
  vim.notify('[Guard]: ' .. msg, vim.log.levels.WARN)
end

-- Main formatting pipeline
local format_buffer = Async.callback(function(ctx, configs, fname, cwd)
  local original_text = ctx:get_text()
  local formatted_text = original_text

  -- Phase 1: Run all pure formatters in sequence
  -- These transform text in memory without side effects
  for _, config in ipairs(configs.pure) do
    -- Check buffer state before each formatter
    if ctx.state:is_modified() then
      return Result.err('Buffer changed during formatting')
    end

    local result
    if config.fn then
      result = Formatters.run_function(ctx.bufnr, ctx.range, config, formatted_text)
    else
      result = Async.await(ctx.ctx:run(Formatters.run_command(config, formatted_text, fname, cwd)))
    end

    if result:is_err() then
      local err = result.error
      if err.type == Async.Error.COMMAND_FAILED then
        local details = err.details
        return Result.err(
          string.format(
            '%s exited with code %d\n%s',
            details.cmd,
            details.code,
            details.stderr or ''
          )
        )
      end
      return result
    end

    -- Update formatted text for next formatter in chain
    formatted_text = config.cmd and result.value.stdout or result.value
  end

  -- Final buffer state check before applying changes
  if ctx.state:is_modified() then
    return Result.err('Buffer changed during formatting')
  end

  if not ctx.state:is_valid() then
    return Result.err('Buffer no longer valid')
  end

  -- Apply pure formatter changes to buffer
  local apply_result = apply_buffer_changes(ctx, original_text, formatted_text)
  if apply_result:is_err() then
    return apply_result
  end

  -- Phase 2: Run impure formatters (if any)
  -- These modify the file directly and must run after buffer is saved
  if #configs.impure > 0 then
    -- Ensure buffer is saved before running impure formatters
    if apply_result.value or vim.bo[ctx.bufnr].modified then
      vim.cmd('silent! write!')
    end

    for _, config in ipairs(configs.impure) do
      local result = Async.await(ctx.ctx:run(Formatters.run_command(config, nil, fname, cwd)))

      if result:is_err() then
        local err = result.error
        if err.type == Async.Error.COMMAND_FAILED then
          local details = err.details
          return Result.err(
            string.format(
              '%s exited with code %d\n%s',
              details.cmd,
              details.code,
              details.stderr or ''
            )
          )
        end
        return result
      end
    end

    -- Reload buffer after impure formatters
    vim.schedule(function()
      if api.nvim_buf_is_valid(ctx.bufnr) then
        api.nvim_buf_call(ctx.bufnr, function()
          ctx.state:save_views()
          vim.cmd('silent! edit!')
          ctx.state:restore_views()
        end)
      end
    end)
  end

  return Result.ok({
    changed = apply_result.value or #configs.impure > 0,
  })
end)

function M.do_fmt(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  local ft = vim.bo[bufnr].filetype
  local ft_conf = filetype[ft]

  if not ft_conf or not ft_conf.formatter then
    notify_error('missing config for filetype ' .. ft)
    return
  end

  -- Determine format range and mode
  local mode = api.nvim_get_mode().mode
  local range = nil

  if mode == 'V' or mode == 'v' then
    range = util.range_from_selection(bufnr, mode)
  end

  local ctx = FormatContext.new(bufnr, range, mode)

  local prepare_result = Formatters.prepare_configs(ft_conf, bufnr)
  if prepare_result:is_err() then
    notify_error(prepare_result.error)
    return
  end

  local configs = prepare_result.value

  local range_validation = Formatters.validate_range_support(configs, range)
  if range_validation:is_err() then
    local err = range_validation.error
    notify_error(string.format('%s\n%s', err.message, err.details))
    return
  end

  local fname, cwd = util.buf_get_info(bufnr)

  send_event('pending', { using = configs.all })

  -- Schedule state initialization to avoid tick change from BufWritePre
  vim.schedule(function()
    ctx.state:save_changedtick()

    -- Run the formatting pipeline
    format_buffer(ctx, configs, fname, cwd)(function(result)
      result:match({
        ok = function(value)
          send_event('done', value)
          if util.getopt('refresh_diagnostic') then
            vim.diagnostic.show()
          end
        end,
        err = function(err)
          notify_error(err)
        end,
      })
    end)
  end)
end

return M
