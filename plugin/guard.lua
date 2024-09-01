local loaded = false
if loaded then
  return
end
loaded = true

local api = vim.api
local events = require('guard.events')

local cmds = {
  fmt = function()
    require('guard.format').do_fmt()
  end,
  enable = function(opts)
    local group = events.group
    local arg = opts.args
    local bufnr = (#opts.fargs == 1) and api.nvim_get_current_buf() or tonumber(arg)
    if not bufnr or not api.nvim_buf_is_valid(bufnr) then
      return
    end
    local bufau = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = bufnr })
    if #bufau == 0 then
      require('guard.events').try_attach_to_buf(bufnr)
    end
  end,
  disable = function(opts)
    local group = events.group
    local arg = opts.args
    local bufnr = (#opts.fargs == 1) and api.nvim_get_current_buf() or tonumber(arg)
    if not bufnr or not api.nvim_buf_is_valid(bufnr) then
      return
    end
    local bufau = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = bufnr })
    if #bufau ~= 0 then
      api.nvim_del_autocmd(bufau[1].id)
    end
  end,
  info = function()
    local util = require('guard.util')
    local group = events.group
    local buf = api.nvim_get_current_buf()
    local ft = require('guard.filetype')[vim.bo[buf].ft] or {}
    local formatters = ft.formatter or {}
    local linters = ft.linter or {}
    local fmtau = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = buf })
    local lintau = api.nvim_get_autocmds({ group = group, event = 'BufWritePost', buffer = buf })
    util.open_info_win()
    local lines = {
      '# Guard info (press Esc or q to close)',
      '## Settings:',
      ('- `fmt_on_save`: %s'):format(util.getopt('fmt_on_save')),
      ('- `lsp_as_default_formatter`: %s'):format(util.getopt('lsp_as_default_formatter')),
      ('- `save_on_fmt`: %s'):format(util.getopt('save_on_fmt')),
      '',
      ('## Current buffer has filetype %s:'):format(vim.bo[buf].ft),
      ('- %s formatter autocmds attached'):format(#fmtau),
      ('- %s linter autocmds attached'):format(#lintau),
      '- formatters:',
      '',
      '```lua',
    }
    for _, formatter in ipairs(formatters) do
      for _, line in ipairs(vim.split(vim.inspect(formatter), '\n')) do
        table.insert(lines, line)
      end
    end
    table.insert(lines, '```')
    table.insert(lines, '')
    table.insert(lines, '- linters:')
    table.insert(lines, '')
    table.insert(lines, '```lua')
    for _, linter in ipairs(linters) do
      for _, line in ipairs(vim.split(vim.inspect(linter), '\n')) do
        table.insert(lines, line)
      end
    end
    table.insert(lines, '```')
    api.nvim_buf_set_lines(0, 0, -1, true, lines)
    api.nvim_set_option_value('modifiable', false, { buf = 0 })
  end,
}

api.nvim_create_user_command('Guard', function(opts)
  local f = cmds[opts.args]
  if f then
    f(opts)
  else
    vim.notify('[Guard]: Invalid subcommand: ' .. opts.args)
  end
end, {
  nargs = '+',
  complete = function(arg_lead, cmdline, _)
    if cmdline:match('Guard*%s+%w*$') then
      return vim
        .iter(vim.tbl_keys(cmds))
        :filter(function(key)
          return key:find(arg_lead) ~= nil
        end)
        :totable()
    end
  end,
})

events.create_lspattach_autocmd()
