local loaded = false
if loaded then
  return
end
loaded = true
vim.api.nvim_create_user_command('GuardDisable', function(opts)
  require('guard.api').disable(opts)
end, { nargs = '?' })
vim.api.nvim_create_user_command('GuardEnable', function(opts)
  require('guard.api').enable(opts)
end, { nargs = '?' })
vim.api.nvim_create_user_command('GuardFmt', function()
  require('guard.format').do_fmt()
end, { nargs = 0 })
