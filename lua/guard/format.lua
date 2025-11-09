local async = require('guard._async')
local util = require('guard.util')
local filetype = require('guard.filetype')
local api, iter, filter = vim.api, vim.iter, vim.tbl_filter

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

local function update_buffer(bufnr, prev_content, new_content, srow, erow, old_indent)
  if not new_content or #new_content == 0 then
    return
  end

  -- Always update if content changed (compare strings directly)
  if prev_content ~= new_content then
    local views = save_views(bufnr)

    local new_lines = vim.split(new_content, '\r?\n')
    if new_lines[#new_lines] == '' then
      new_lines[#new_lines] = nil
    end

    api.nvim_buf_set_lines(bufnr, srow, erow, false, new_lines)

    if util.getopt('save_on_fmt') then
      api.nvim_command('silent! noautocmd write!')
    end

    if old_indent then
      vim.cmd(('silent %d,%dleft'):format(srow + 1, erow))
    end

    restore_views(views)
  end
end

local function fail(msg)
  util.doau('GuardFmt', {
    status = 'failed',
    msg = msg,
  })
  vim.notify('[Guard]: ' .. msg, vim.log.levels.WARN)
end

local function do_fmt(buf)
  buf = buf or api.nvim_get_current_buf()
  local ft_conf = filetype[vim.bo[buf].filetype]

  if not ft_conf or not ft_conf.formatter then
    util.report_error('missing config for filetype ' .. vim.bo[buf].filetype)
    return
  end

  local srow, erow = 0, -1
  local range = nil
  local mode = api.nvim_get_mode().mode
  if mode == 'V' or mode == 'v' then
    range = util.range_from_selection(buf, mode)
    srow = range.start[1] - 1
    erow = range['end'][1]
  end

  local old_indent
  if mode == 'V' then
    old_indent = vim.fn.indent(srow + 1)
  end

  local fmt_configs = util.eval(ft_conf.formatter)
  local fname, cwd = util.buf_get_info(buf)

  fmt_configs = filter(function(config)
    return util.should_run(config, buf)
  end, fmt_configs)

  local all_executable = not iter(fmt_configs):any(function(config)
    if config.cmd and vim.fn.executable(config.cmd) ~= 1 then
      util.report_error(config.cmd .. ' not executable')
      return true
    end
    return false
  end)

  if not all_executable then
    return
  end

  local pure = filter(function(config)
    return config.fn or (config.cmd and config.stdin)
  end, fmt_configs)

  local impure = filter(function(config)
    return config.cmd and not config.stdin
  end, fmt_configs)

  if range and #impure > 0 then
    util.report_error('Cannot apply range formatting for filetype ' .. vim.bo[buf].filetype)
    local impure_cmds = {}
    for _, config in ipairs(impure) do
      table.insert(impure_cmds, config.cmd)
    end
    util.report_error(table.concat(impure_cmds, ', ') .. ' does not support reading from stdin')
    return
  end

  util.doau('GuardFmt', {
    status = 'pending',
    using = fmt_configs,
  })

  local prev_lines = api.nvim_buf_get_lines(buf, srow, erow, false)
  local prev_content = table.concat(prev_lines, '\n')
  local new_lines = prev_content
  local errno = nil

  async.run(function()
    -- Explicitly wait for changedtick initialization
    local changedtick = async.await(1, function(callback)
      vim.schedule(function()
        callback(api.nvim_buf_get_changedtick(buf))
      end)
    end)

    -- Apply pure formatters sequentially
    for _, config in ipairs(pure) do
      if errno then
        break
      end

      -- Eval dynamic args
      local cfg = vim.tbl_extend('force', {}, config)
      if type(cfg.args) == 'function' then
        cfg.args = cfg.args(buf)
      end

      if cfg.fn then
        new_lines = cfg.fn(buf, range, new_lines)
      else
        local result = async.await(1, function(callback)
          local handle = vim.system(util.get_cmd(cfg, fname, buf), {
            stdin = true,
            cwd = cwd,
            env = cfg.env,
            timeout = cfg.timeout,
          }, callback)
          handle:write(new_lines)
          handle:write(nil)
        end)

        if result.code ~= 0 and #result.stderr > 0 then
          errno = {
            cmd = cfg.cmd,
            code = result.code,
            stderr = result.stderr,
            reason = cfg.cmd .. ' exited with errors',
          }
        else
          new_lines = result.stdout
        end
      end
    end

    -- Wait for schedule and update buffer
    async.await(1, function(callback)
      vim.schedule(function()
        if errno then
          if errno.reason:match('exited with errors$') then
            fail(('%s exited with code %d\n%s'):format(errno.cmd, errno.code, errno.stderr))
          elseif errno.reason == 'buffer changed' then
            fail('buffer changed during formatting')
          else
            fail(errno.reason)
          end
          callback()
          return
        end

        if api.nvim_buf_get_changedtick(buf) ~= changedtick then
          fail('buffer changed during formatting')
          callback()
          return
        end

        if not api.nvim_buf_is_valid(buf) then
          fail('buffer no longer valid')
          callback()
          return
        end

        update_buffer(buf, prev_content, new_lines, srow, erow, old_indent)
        callback()
      end)
    end)

    -- Stop if there was an error
    if errno then
      return
    end

    -- Apply impure formatters sequentially
    local impure_error = nil
    for _, config in ipairs(impure) do
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
        }, callback)
      end)

      if result.code ~= 0 and #result.stderr > 0 then
        impure_error = {
          cmd = cfg.cmd,
          code = result.code,
          stderr = result.stderr,
        }
        break
      end
    end

    if impure_error then
      fail(
        ('%s exited with code %d\n%s'):format(
          impure_error.cmd,
          impure_error.code,
          impure_error.stderr
        )
      )
      return
    end

    if #impure > 0 then
      vim.schedule(function()
        api.nvim_buf_call(buf, function()
          local views = save_views(buf)
          api.nvim_command('silent! edit!')
          restore_views(views)
        end)
      end)
    end

    util.doau('GuardFmt', {
      status = 'done',
    })

    if util.getopt('refresh_diagnostic') then
      vim.diagnostic.show()
    end
  end)
end

return {
  do_fmt = do_fmt,
}
