local api = vim.api
local uv = vim.uv
local spawn = require('guard.spawn')
local util = require('guard.util')
local get_prev_lines = util.get_prev_lines
local filetype = require('guard.filetype')

local function ignored(buf, patterns)
  local fname = api.nvim_buf_get_name(buf)
  if #fname == 0 then
    return false
  end

  for _, pattern in pairs(util.as_table(patterns)) do
    if fname:find(pattern) then
      return true
    end
  end
  return false
end

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

local function find(startpath, patterns, root_dir)
  patterns = util.as_table(patterns)
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
end

local function get_cmd(config, fname)
  local cmd = config.args or {}
  table.insert(cmd, 1, config.cmd)
  if config.fname then
    table.insert(cmd, fname)
  end
  return cmd
end

local function do_fmt(buf)
  buf = buf or api.nvim_get_current_buf()
  if not filetype[vim.bo[buf].filetype] then
    vim.notify('[Guard] missing config for filetype ' .. vim.bo[buf].filetype, vim.log.levels.ERROR)
    return
  end

  local srow = 0
  local erow = -1
  local range
  local mode = api.nvim_get_mode().mode
  if mode == 'V' or mode == 'v' then
    range = util.range_from_selection(buf, mode)
    srow = range.start[1] - 1
    erow = range['end'][1]
  end

  local fmt_configs = filetype[vim.bo[buf].filetype].formatter
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  ---@diagnostic disable-next-line: param-type-mismatch
  local startpath = vim.fn.expand(fname, ':p:h')
  local root_dir = util.get_lsp_root()
  ---@diagnostic disable-next-line: undefined-field
  local cwd = root_dir or uv.cwd()

  util.doau('GuardFmt', {
    status = 'pending',
    using = fmt_configs,
  })
  local prev_lines = table.concat(get_prev_lines(buf, srow, erow), '')

  coroutine.resume(coroutine.create(function()
    local new_lines = prev_lines
    local changedtick = api.nvim_buf_get_changedtick(buf)
    local error = false
    local error_cmd = ''

    -- handle execution condition
    fmt_configs = fmt_configs.filter(function(config)
      if config.ignore_patterns and ignored(buf, config.ignore_patterns) then
        return false
      elseif config.ignore_error and #vim.diagnostic.get(buf, { severity = 1 }) ~= 0 then
        return false
      elseif config.find and not find(startpath, config.find, root_dir) then
        return false
      end
      return true
    end)

    -- filter out pure and impure formatters
    local pure = vim.iter(fmt_configs):filter(function(config)
      return config.fn or (config.cmd and config.stdin)
    end)
    local impure = vim.iter(fmt_configs):filter(function(config)
      return config.cmd and not config.stdin
    end)

    -- error if one of the formatters is impure and the user requested range formatting
    if range and #impure:totable() > 0 then
      local error_msg = '[Guard]: Cannot apply range formatting for filetype `'
        .. vim.bo[buf].filetype
        .. '` because the following formatters\n'
        .. vim.inspect(#impure:totable())
        .. '\n does not support reading from stdin'
      util.doau('GuardFmt', {
        status = 'failed',
        msg = 'range formatting requested with non-capable formatters',
      })
      vim.notify(error_msg, 4)
      return
    end

    new_lines = pure:fold(new_lines, function(acc, _, config)
      -- we don't need to reformat an empty string
      if new_lines == '' then
        return ''
      end
      if config.fn then
        return config.fn(buf, range, acc)
      else
        local result = spawn.transform(get_cmd(config, fname), cwd, config.env or {}, acc)
        if type(result) == 'number' then
          -- indicates error
          error = true
          error_cmd = config.cmd
          return ''
        else
          return result
        end
      end
    end)

    if error then
      util.doau('GuardFmt', {
        status = 'failed',
        msg = error_cmd .. ' exited with non-zero exit code',
      })
      vim.notify('[Guard]: ' .. error_cmd .. ' exited with errors', 4)
      return
    end

    if not api.nvim_buf_is_valid(buf) or changedtick ~= api.nvim_buf_get_changedtick(buf) then
      util.doau('GuardFmt', {
        status = 'failed',
        msg = 'buffer changed or no longer valid',
      })
      return
    end

    update_buffer(buf, prev_lines, new_lines, srow, erow)

    impure:each(function(config)
      vim
        .system(get_cmd(config, fname), {
          text = true,
          cwd = cwd,
          env = config.env or {},
        }, function(handle)
          if handle.code ~= 0 and #handle.stderr > 0 then
            error = true
            error_cmd = config.cmd
          end
        end)
        :wait()
    end)

    if error then
      util.doau('GuardFmt', {
        status = 'failed',
        msg = error_cmd .. ' exited with non-zero exit code',
      })
      vim.notify('[Guard]: ' .. error_cmd .. ' exited with errors', 4)
      return
    end

    if #impure:totable() > 0 and api.nvim_get_current_buf() == buf then
      vim.cmd.edit()
    end

    util.doau('GuardFmt', {
      status = 'done',
      results = new_lines,
    })
  end))
end

return {
  do_fmt = do_fmt,
}
