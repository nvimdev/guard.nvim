local api = vim.api
local group = api.nvim_create_augroup('guard', { clear = true })

local function register_command()
  api.nvim_create_user_command('GuardFmt', function()
    require('guard.format').do_fmt()
  end, {})

  api.nvim_create_user_command('GuardLint', function()
    require('guard.lint').do_lint()
  end, {})
end

local function register_event(fts)
  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = fts,
    callback = function(args)
      api.nvim_create_autocmd('BufWritePre', {
        group = group,
        buffer = args.buf,
        callback = function()
          require('guard.format').do_fmt(args.buf)
        end,
      })
    end,
    desc = 'guard',
  })

  api.nvim_create_user_command('GuardDisable', function()
    api.nvim_del_augroup_by_id(group)
  end, {})
end

local function setup(opt)
  local fts_config = require('guard.filetype')
  if opt.fmt_on_save then
    register_event(vim.tbl_keys(fts_config))
  end

  register_command()
end

return {
  setup = setup,
}
