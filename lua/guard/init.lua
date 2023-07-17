local api = vim.api
local group = api.nvim_create_augroup('Guard', { clear = true })

local function parse_ft_config(config)
  config = config or {}
  for ft, ft_config in pairs(config.ft) do
    local cfg_handler = require('guard.filetype')(ft)
    for key, cfg in pairs(ft_config) do
      if key == 'lint' then
        if vim.tbl_islist(cfg) then
          for _, linter_cfg in ipairs(cfg) do
            cfg_handler = cfg_handler:lint(linter_cfg)
          end
        else
          cfg_handler = cfg_handler:lint(cfg)
        end
      elseif key == 'fmt' then
        if vim.tbl_islist(cfg) then
          for _, formatter_cfg in ipairs(cfg) do
            cfg_handler = cfg_handler:fmt(formatter_cfg)
          end
        else
          cfg_handler = cfg_handler:fmt(cfg)
        end
      elseif key == 'append' then
        if vim.tbl_islist(cfg) then
          for _, other_cfg in ipairs(cfg) do
            cfg_handler = cfg_handler:append(other_cfg)
          end
        else
          cfg_handler = cfg_handler:append(cfg)
        end
      end
    end
  end
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
  opt = opt or {
    fmt_on_save = true,
  }
  parse_ft_config(opt)
  local fts_config = require('guard.filetype')
  if opt.fmt_on_save then
    register_event(vim.tbl_keys(fts_config))
  end

  local lint = require('guard.lint')
  for ft, conf in pairs(fts_config) do
    if conf.linter then
      for i, entry in ipairs(conf.linter) do
        if type(entry) == 'string' then
          local tool = require('guard.tools.linter.' .. entry)
          if tool then
            conf.linter[i] = tool
          end
        end

        lint.register_lint(
          ft,
          conf.linter[i].stdin and { 'TextChanged', 'InsertLeave' } or { 'BufWritePost' }
        )
      end
    end
  end
end

return {
  setup = setup,
}
