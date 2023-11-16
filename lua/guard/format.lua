local api = vim.api
---@diagnostic disable-next-line: deprecated
local uv = vim.version().minor >= 10 and vim.uv or vim.loop
local spawn = require('guard.spawn').try_spawn
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

local function update_buffer(bufnr, prev_lines, new_lines)
  if not new_lines or #new_lines == 0 then
    return
  end
  local views = save_views(bufnr)
  new_lines = vim.split(new_lines, '\n')
  if new_lines[#new_lines] == '' then
    new_lines[#new_lines] = nil
  end

  if #new_lines ~= #prev_lines then
    api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
    api.nvim_command('silent! noautocmd write!')
    restore_views(views)
    return
  end

  --TODO(glpnir): before use diff update minimal area has bug line flush
  --not correct so retrun to update whole buffer.
  local diffs = vim.diff(table.concat(new_lines, '\n'), prev_lines, {
    algorithm = 'minimal',
    ctxlen = 0,
    result_type = 'indices',
  })
  if not diffs or #diffs == 0 then
    return
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
  api.nvim_command('silent! noautocmd write!')
  restore_views(views)
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

local function override_lsp(buf)
  local co = assert(coroutine.running())
  local original = vim.lsp.util.apply_text_edits
  local clients = util.get_clients(buf, 'textDocument/formatting')
  if #clients == 0 then
    return
  end
  local total = #clients

  local changed_tick = api.nvim_buf_get_changedtick(buf)
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.apply_text_edits = function(text_edits, bufnr, offset_encoding)
    total = total - 1
    original(text_edits, bufnr, offset_encoding)
    if api.nvim_buf_get_changedtick(buf) ~= changed_tick then
      api.nvim_command('silent! noautocmd write!')
    end
    if total == 0 then
      coroutine.resume(co)
    end
  end
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
  local startpath = vim.fn.expand(fname, ':p:h')
  local root_dir = util.get_lsp_root()
  local cwd = root_dir or uv.cwd()
  util.doau('GuardFmt', {
    status = 'pending',
    using = fmt_configs,
  })
  local prev_lines = table.concat(get_prev_lines(buf, srow, erow), '')

  coroutine.resume(coroutine.create(function()
    local new_lines
    local changedtick = api.nvim_buf_get_changedtick(buf)
    local reload = nil

    for i, config in ipairs(fmt_configs) do
      local allow = true
      if config.ignore_patterns and ignored(buf, config.ignore_patterns) then
        allow = false
      elseif config.ignore_error and #vim.diagnostic.get(buf, { severity = 1 }) ~= 0 then
        allow = false
      elseif config.find and not find(startpath, config.find, root_dir) then
        allow = false
      end

      if allow then
        if config.cmd then
          config.lines = new_lines and new_lines or prev_lines
          config.args = config.args or {}
          config.args[#config.args + 1] = config.fname and fname or nil
          config.cwd = cwd
          reload = (not reload and config.stdout == false) and true or false
          new_lines = spawn(config)
          --restore
          config.lines = nil
          config.cwd = nil
          if config.fname then
            config.args[#config.args] = nil
          end
        elseif config.fn then
          if not config.override then
            override_lsp(buf)
            config.override = true
          end
          config.fn(buf, range)
          coroutine.yield()
          if i ~= #fmt_configs then
            new_lines = table.concat(get_prev_lines(buf, srow, erow), '')
          end
        end
        changedtick = vim.b[buf].changedtick
      end
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) or changedtick ~= api.nvim_buf_get_changedtick(buf) then
        util.doau('GuardFmt', {
          status = 'failed',
          msg = 'buffer changed or no longer valid',
        })
        return
      end
      update_buffer(buf, prev_lines, new_lines)
      if reload and api.nvim_get_current_buf() == buf then
        vim.cmd.edit()
      end
      util.doau('GuardFmt', {
        status = 'done',
        results = new_lines,
      })
    end)
  end))
end

local function attach_to_buf(buf)
  api.nvim_create_autocmd('BufWritePre', {
    group = require('guard.events').group,
    buffer = buf,
    callback = function(opt)
      if not vim.bo[opt.buf].modified then
        return
      end
      require('guard.format').do_fmt(opt.buf)
    end,
  })
end

return {
  do_fmt = do_fmt,
  attach_to_buf = attach_to_buf,
}
