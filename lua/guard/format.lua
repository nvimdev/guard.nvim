local api = vim.api
---@diagnostic disable-next-line: deprecated
local uv = vim.version().minor >= 10 and vim.uv or vim.loop
local spawn = require('guard.spawn').try_spawn
local get_prev_lines = require('guard.util').get_prev_lines
local filetype = require('guard.filetype')
local formatter = require('guard.tools.formatter')
local util = require('guard.util')

local function ignored(buf, patterns)
  local fname = api.nvim_buf_get_name(buf)
  if #fname == 0 then
    return false
  end

  for _, pattern in pairs(patterns) do
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

local function update_buffer(bufnr, new_lines, srow, erow)
  if not new_lines or #new_lines == 0 then
    return
  end
  local views = save_views(bufnr)

  local prev_lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow, true)
  new_lines = vim.split(new_lines, '\n')
  if new_lines[#new_lines] == 0 then
    new_lines[#new_lines] = nil
  end
  local diffs = vim.diff(table.concat(new_lines, '\n'), table.concat(prev_lines, '\n'), {
    algorithm = 'minimal',
    ctxlen = 0,
    result_type = 'indices',
  })
  if not diffs or #diffs == 0 then
    return
  end

  -- Apply diffs in reverse order.
  for i = #diffs, 1, -1 do
    local new_start, new_count, prev_start, prev_count = unpack(diffs[i])
    local replacement = {}
    for j = new_start, new_start + new_count - 1, 1 do
      replacement[#replacement + 1] = new_lines[j]
    end
    local s, e
    if prev_count == 0 then
      s = prev_start
      e = s
    else
      s = prev_start - 1 + srow
      e = s + prev_count
    end
    api.nvim_buf_set_lines(bufnr, s, e, false, replacement)
  end
  api.nvim_command('silent! noautocmd write!')
  local mode = api.nvim_get_mode().mode
  if mode == 'v' or 'V' then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
  end
  restore_views(views)
end

local function find(startpath, patterns, root_dir)
  patterns = util.as_table(patterns)
  for _, pattern in ipairs(patterns) do
    if
      #vim.fs.find(pattern, { upward = true, stop = root_dir or vim.env.HOME, path = startpath })
      > 0
    then
      return true
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
  local mode = api.nvim_get_mode().mode
  if mode == 'V' or mode == 'v' then
    srow = vim.fn.getpos('v')[2] - 1
    erow = vim.fn.getpos('.')[2]
  end
  local prev_lines = util.get_prev_lines(buf, srow, erow)

  local fmt_configs = filetype[vim.bo[buf].filetype].format
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  local startpath = vim.fn.expand(fname, ':p:h')
  local root_dir = util.get_lsp_root()
  local cwd = root_dir or uv.cwd()

  coroutine.resume(coroutine.create(function()
    local new_lines
    local changedtick = api.nvim_buf_get_changedtick(buf)
    local reload = nil

    for i, config in ipairs(fmt_configs) do
      if type(config) == 'string' and formatter[config] then
        config = formatter[config]
      end

      local can_run = true
      if config.ignore_patterns and ignored(buf, configs.ignore_patterns) then
        can_run = false
      elseif config.ignore_error and #vim.diagnostic.get(buf, { severity = 1 }) ~= 0 then
        can_run = false
      elseif config.find and not find(startpath, config.find, root_dir) then
        can_run = false
      end

      if can_run then
        if config.cmd then
          config.lines = new_lines and new_lines or prev_lines
          config.args[#config.args + 1] = config.fname and fname or nil
          config.cwd = cwd
          reload = (not reload and config.stdout == false) and true or false
          new_lines = spawn(config)
          --restore
          config.lines = nil
          config.cwd = nil
          if config.args[#config.args] == fname then
            config.args[#config.args] = nil
          end
        elseif config.fn then
          config.fn()
          if i == #fmt_configs then
            return
          end
          new_lines = table.concat(get_prev_lines(buf, srow, erow), '')
        end
        changedtick = vim.b[buf].changedtick
      end
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) or changedtick ~= api.nvim_buf_get_changedtick(buf) then
        return
      end
      update_buffer(buf, new_lines, srow, erow)
      if reload and api.nvim_get_current_buf() == buf then
        vim.cmd.edit()
      end
    end)
  end))
end

return {
  do_fmt = do_fmt,
}
