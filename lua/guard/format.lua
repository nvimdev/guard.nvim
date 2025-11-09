local async = require('guard._async')
local util = require('guard.util')
local filetype = require('guard.filetype')
local api = vim.api

local M = {}

local function save_views(bufnr)
  local views = {}
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    views[win] = api.nvim_win_call(win, vim.fn.winsaveview)
  end
  return views
end

local function restore_views(views)
  for win, view in pairs(views) do
    api.nvim_win_call(win, function()
      vim.fn.winrestview(view)
    end)
  end
end

local function update_buffer(bufnr, prev_lines, new_lines, srow, erow, old_indent)
  if not new_lines or #new_lines == 0 then
    return
  end

  local views = save_views(bufnr)
  new_lines = vim.split(new_lines, '\r?\n')
  if new_lines[#new_lines] == '' then
    new_lines[#new_lines] = nil
  end

  local need_write = false
  if not vim.deep_equal(new_lines, prev_lines) then
    need_write = true
    api.nvim_buf_set_lines(bufnr, srow, erow, false, new_lines)
    if old_indent then
      vim.cmd(('silent %d,%dleft'):format(srow + 1, erow))
    end
    restore_views(views)
  end

  if need_write or util.getopt('save_on_fmt') then
    api.nvim_command('silent! noautocmd write!')
  end
end

local function emit_event(status, data)
  util.doau('GuardFmt', vim.tbl_extend('force', { status = status }, data or {}))
end

local function fail(msg)
  emit_event('failed', { msg = msg })
  vim.notify('[Guard]: ' .. msg, vim.log.levels.WARN)
end

---Apply a single pure formatter
---@async
---@param buf number
---@param range table?
---@param config table
---@param fname string
---@param cwd string
---@param input string
---@return string? output
---@return string? error_msg
local function apply_pure_formatter(buf, range, config, fname, cwd, input)
  -- Eval dynamic args
  local cfg = vim.tbl_extend('force', {}, config)
  if type(cfg.args) == 'function' then
    cfg.args = cfg.args(buf)
  end

  if cfg.fn then
    return cfg.fn(buf, range, input), nil
  end

  local result = async.await(1, function(callback)
    local handle = vim.system(util.get_cmd(cfg, fname, buf), {
      stdin = true,
      cwd = cwd,
      env = cfg.env,
      timeout = cfg.timeout,
    }, callback)
    handle:write(input)
    handle:write(nil)
  end)

  if result.code ~= 0 and #result.stderr > 0 then
    return nil, ('%s exited with code %d\n%s'):format(cfg.cmd, result.code, result.stderr)
  end

  return result.stdout, nil
end

---Apply a single impure formatter
---@async
---@param buf number
---@param config table
---@param fname string
---@param cwd string
---@return string? error_msg
local function apply_impure_formatter(buf, config, fname, cwd)
  -- Eval dynamic args
  local cfg = vim.tbl_extend('force', {}, config)
  if type(cfg.args) == 'function' then
    cfg.args = cfg.args(buf)
  end

  local result = async.await(1, function(callback)
    vim.system(util.get_cmd(cfg, fname, buf), {
      text = true,
      cwd = cwd,
      env = cfg.env or {},
      timeout = cfg.timeout,
    }, callback)
  end)

  if result.code ~= 0 and #result.stderr > 0 then
    return ('%s exited with code %d\n%s'):format(cfg.cmd, result.code, result.stderr)
  end

  return nil
end

local function do_fmt(buf)
  buf = buf or api.nvim_get_current_buf()
  local ft_conf = filetype[vim.bo[buf].filetype]

  if not ft_conf or not ft_conf.formatter then
    util.report_error('missing config for filetype ' .. vim.bo[buf].filetype)
    return
  end

  -- Get format range
  local srow, erow = 0, -1
  local range = nil
  local mode = api.nvim_get_mode().mode
  if mode == 'V' or mode == 'v' then
    range = util.range_from_selection(buf, mode)
    srow = range.start[1] - 1
    erow = range['end'][1]
  end

  local old_indent = (mode == 'V') and vim.fn.indent(srow + 1) or nil

  -- Get and filter configs
  local fmt_configs = util.eval(ft_conf.formatter)
  local fname, cwd = util.buf_get_info(buf)

  fmt_configs = vim.tbl_filter(function(config)
    return util.should_run(config, buf)
  end, fmt_configs)

  -- Check executability
  for _, config in ipairs(fmt_configs) do
    if config.cmd and vim.fn.executable(config.cmd) ~= 1 then
      util.report_error(config.cmd .. ' not executable')
      return
    end
  end

  -- Classify formatters
  local pure = vim.tbl_filter(function(config)
    return config.fn or (config.cmd and config.stdin)
  end, fmt_configs)

  local impure = vim.tbl_filter(function(config)
    return config.cmd and not config.stdin
  end, fmt_configs)

  -- Check range formatting compatibility
  if range and #impure > 0 then
    local impure_cmds = vim.tbl_map(function(c)
      return c.cmd
    end, impure)
    util.report_error('Cannot apply range formatting for filetype ' .. vim.bo[buf].filetype)
    util.report_error(table.concat(impure_cmds, ', ') .. ' does not support reading from stdin')
    return
  end

  emit_event('pending', { using = fmt_configs })

  async.run(function()
    -- Initialize changedtick BEFORE any formatting (explicitly wait)
    local changedtick = async.await(1, function(callback)
      vim.schedule(function()
        callback(api.nvim_buf_get_changedtick(buf))
      end)
    end)

    local prev_lines = api.nvim_buf_get_lines(buf, srow, erow, false)
    local new_lines = table.concat(prev_lines, '\n')

    -- Apply pure formatters sequentially
    for _, config in ipairs(pure) do
      local output, err = apply_pure_formatter(buf, range, config, fname, cwd, new_lines)
      if err then
        fail(err)
        return
      end
      new_lines = output
    end

    async.await(1, function(callback)
      vim.schedule(function()
        if not api.nvim_buf_is_valid(buf) then
          fail('buffer no longer valid')
          callback()
          return
        end

        if api.nvim_buf_get_changedtick(buf) ~= changedtick then
          fail('buffer changed during formatting')
          callback()
          return
        end

        update_buffer(buf, prev_lines, new_lines, srow, erow, old_indent)
        callback()
      end)
    end)

    -- Apply impure formatters sequentially
    for _, config in ipairs(impure) do
      local err = apply_impure_formatter(buf, config, fname, cwd)
      if err then
        fail(err)
        return
      end
    end

    -- Refresh buffer if impure formatters were used
    if #impure > 0 then
      async.await(1, function(callback)
        vim.schedule(function()
          api.nvim_buf_call(buf, function()
            local views = save_views(buf)
            api.nvim_command('silent! edit!')
            restore_views(views)
          end)
          callback()
        end)
      end)
    end

    emit_event('done')

    if util.getopt('refresh_diagnostic') then
      vim.diagnostic.show()
    end
  end)
end

M.do_fmt = do_fmt

return M
