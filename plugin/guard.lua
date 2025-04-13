local loaded = false
if loaded then
  return
end
loaded = true

local api = vim.api
local events = require('guard.events')
local ft_handler = require('guard.filetype')

local cmds = {
  fmt = function()
    require('guard.api').fmt()
  end,

  lint = function()
    require('guard.api').lint()
  end,

  ['enable-fmt'] = function()
    require('guard.api').enable_fmt()
  end,

  ['disable-fmt'] = function()
    require('guard.api').disable_fmt()
  end,

  ['enable-lint'] = function()
    require('guard.api').enable_lint()
  end,

  ['disable-lint'] = function()
    require('guard.api').disable_lint()
    vim.diagnostic.reset(api.nvim_get_namespaces()['Guard'])
  end,

  info = function()
    require('guard.api').info()
  end,
}

api.nvim_create_user_command('Guard', function(opts)
  local f = cmds[opts.args]
    or function()
      vim.notify('[Guard]: Invalid subcommand: ' .. opts.args)
    end
  f()
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

for _, buf in ipairs(api.nvim_list_bufs()) do
  if api.nvim_buf_is_loaded(buf) then
    if
      vim.iter(vim.lsp.get_clients({ bufnr = buf })):any(function(c)
        return c:supports_method('textDocument/formatting')
      end)
    then
      local ft = vim.bo[buf].ft
      events.maybe_default_to_lsp(ft_handler(ft), ft, buf)
    end
  end
end
