local loaded = false
if loaded then
  return
end
loaded = true

local api = vim.api
local group = require('guard.events').group

vim.api.nvim_create_user_command('GuardDisable', function(opts)
  local arg = opts.args
  local bufnr = (#opts.fargs == 0) and api.nvim_get_current_buf() or tonumber(arg)
  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local bufau = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = bufnr })
  if #bufau ~= 0 then
    api.nvim_del_autocmd(bufau[1].id)
  end
end, { nargs = '?' })

vim.api.nvim_create_user_command('GuardEnable', function(opts)
  local arg = opts.args
  local bufnr = (#opts.fargs == 0) and api.nvim_get_current_buf() or tonumber(arg)
  if bufnr then
    local bufau = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = bufnr })
    if #bufau == 0 then
      require('guard.format').attach_to_buf(bufnr)
    end
  end
end, { nargs = '?' })

vim.api.nvim_create_user_command('GuardFmt', function()
  require('guard.format').do_fmt()
end, { nargs = 0 })
vim.api.nvim_create_user_command('GuardFmtNoSave', function()
  require('guard.format').do_fmt(nil, false)
end, { nargs = 0 })
