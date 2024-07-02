---@class FmtConfig
---@field cmd string?
---@field args string[]?
---@field fname boolean?
---@field stdin boolean?
---@field fn function?
---@field ignore_patterns string[]?
---@field ignore_error boolean?
---@field find string|string[]?
---@field env table<string, string>?
---@field timeout integer?

local api = vim.api
local spawn = require('guard.spawn')
local util = require('guard.util')
local error = util.error
local filetype = require('guard.filetype')
local iter, filter = vim.iter, vim.tbl_filter

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

local function update_buffer(bufnr, prev_lines, new_lines, srow, erow)
  if not new_lines or #new_lines == 0 then
    return
  end
  local views = save_views(bufnr)
  -- \r\n for windows compatibility
  new_lines = vim.split(new_lines, '\r?\n')
  if new_lines[#new_lines] == '' then
    new_lines[#new_lines] = nil
  end

  if new_lines ~= prev_lines then
    api.nvim_buf_set_lines(bufnr, srow, erow, false, new_lines)
    if require('guard').config.opts.save_on_fmt then
      api.nvim_command('silent! noautocmd write!')
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
    error('missing config for filetype ' .. vim.bo[buf].filetype)
    return
  end

  -- get format range
  local srow, erow = 0, -1
  local range = nil
  local mode = api.nvim_get_mode().mode
  if mode == 'V' or mode == 'v' then
    range = util.range_from_selection(buf, mode)
    srow = range.start[1] - 1
    erow = range['end'][1]
  end

  -- init environment
  ---@type FmtConfig[]
  local fmt_configs = ft_conf.formatter
  local fname, startpath, root_dir, cwd = util.buf_get_info(buf)

  -- handle execution condition
  fmt_configs = filter(function(config)
    return util.should_run(config, buf, startpath, root_dir)
  end, fmt_configs)

  -- check if all cmds executable
  local non_excutable = filter(function(config)
    return config.cmd and vim.fn.executable(config.cmd) ~= 1
  end, fmt_configs)

  if #non_excutable > 0 then
    error(('%s not executable'):format(table.concat(
      vim.tbl_map(function(config)
        return config.cmd
      end, non_excutable),
      ', '
    )))
  end

  -- filter out "pure" and "impure" formatters
  local pure = iter(filter(function(config)
    return config.fn or (config.cmd and config.stdin)
  end, fmt_configs))
  local impure = iter(filter(function(config)
    return config.cmd and not config.stdin
  end, fmt_configs))

  -- error if one of the formatters is impure and the user requested range formatting
  if range and #impure:totable() > 0 then
    error('Cannot apply range formatting for filetype ' .. vim.bo[buf].filetype)
    error(impure
      :map(function(config)
        return config.cmd or '<fn>'
      end)
      :join(', ') .. ' does not support reading from stdin')
    return
  end

  -- actually start formatting
  util.doau('GuardFmt', {
    status = 'pending',
    using = fmt_configs,
  })

  local prev_lines = table.concat(util.get_prev_lines(buf, srow, erow), '')
  local new_lines = prev_lines
  local errno = nil

  coroutine.resume(coroutine.create(function()
    local changedtick = -1
    -- defer initialization, since BufWritePre would trigger a tick change
    vim.schedule(function()
      changedtick = api.nvim_buf_get_changedtick(buf)
    end)
    new_lines = pure:fold(new_lines, function(acc, config, _)
      -- check if we are in a valid state
      vim.schedule(function()
        if api.nvim_buf_get_changedtick(buf) ~= changedtick then
          errno = { reason = 'buffer changed' }
        end
      end)
      if errno then
        return ''
      end

      -- NB: we rely on the `fn` and spawn.transform to yield the coroutine
      if config.fn then
        return config.fn(buf, range, acc)
      else
        config.cwd = config.cwd or cwd
        local result = spawn.transform(util.get_cmd(config, fname), config, acc)
        if type(result) == 'table' then
          -- indicates error
          errno = result
          errno.reason = config.cmd .. ' exited with errors'
          return ''
        else
          ---@diagnostic disable-next-line: return-type-mismatch
          return result
        end
      end
    end)

    local co = assert(coroutine.running())

    vim.schedule(function()
      -- handle errors
      if errno then
        if errno.reason == 'exit with errors' then
          fail(('%s exited with code %d\n%s'):format(errno.cmd, errno.code, errno.stderr))
        elseif errno.reason == 'buf changed' then
          fail('buffer changed during formatting')
        else
          fail(errno.reason)
        end
        return
      end
      -- check buffer one last time
      if api.nvim_buf_get_changedtick(buf) ~= changedtick then
        fail('buffer changed during formatting')
      end
      if not api.nvim_buf_is_valid(buf) then
        fail('buffer no longer valid')
        return
      end
      update_buffer(buf, prev_lines, new_lines, srow, erow)
      coroutine.resume(co)
    end)

    -- wait until substitution is finished
    coroutine.yield()

    impure:fold(nil, function(_, config, _)
      if errno then
        return
      end

      vim.system(util.get_cmd(config, fname), {
        text = true,
        cwd = cwd,
        env = config.env or {},
      }, function(result)
        if result.code ~= 0 and #result.stderr > 0 then
          errno = result
          ---@diagnostic disable-next-line: inject-field
          errno.cmd = config.cmd
          coroutine.resume(co)
        else
          coroutine.resume(co)
        end
      end)

      coroutine.yield()
    end)

    if errno then
      fail(('%s exited with code %d\n%s'):format(errno.cmd, errno.code, errno.stderr))
      return
    end

    -- refresh buffer
    vim.schedule(function()
      api.nvim_buf_call(buf, function()
        local views = save_views(buf)
        api.nvim_command('silent! edit!')
        restore_views(views)
      end)
    end)

    util.doau('GuardFmt', {
      status = 'done',
    })
  end))
end

return {
  do_fmt = do_fmt,
}
