local loaded = false
if loaded then
  return
end
loaded = true

vim.api.nvim_create_user_command('GuardFmt', function()
  require('guard.format').do_fmt()
end, {})
