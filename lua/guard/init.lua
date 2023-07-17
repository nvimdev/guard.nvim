local api = vim.api
local group = api.nvim_create_augroup('Guard', { clear = true })
local fts_config = require('guard.filetype')
local util = require('guard.util')
local config = require('guard.config')

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
    pcall(api.nvim_del_augroup_by_id, group)
  end, {})
end

local function parse_setup_cfg(fts_with_cfg)
  for ft, cfg in pairs(fts_with_cfg or {}) do
    if not vim.tbl_isempty(cfg) then
      local handler = fts_config(ft)
      local keys = vim.tbl_keys(cfg)
      vim.tbl_map(function(key)
        handler:register(key, util.as_table(cfg[key]))
      end, keys)
    end
  end
end

local function get_fts_keys()
  local keys = vim.tbl_keys(fts_config)
  local retval = {}
  vim.tbl_map(function(key)
    if key:find(',') then
      local t = vim.split(key, ',')
      for _, item in ipairs(t) do
        fts_config[item] = vim.deepcopy(fts_config[key])
        retval[#retval + 1] = item
      end
    else
      retval[#retval + 1] = key
    end
  end, keys)
  return retval
end

local function setup(opt)
  opt = opt or {
    fmt_on_save = true,
    lsp_as_default_formatter = false,
  }

  parse_setup_cfg(opt.ft)
  local fts = get_fts_keys()

  if opt.fmt_on_save then
    register_event(fts)
  end

  if opt.lsp_as_default_formatter then
    config.lsp_as_default_formatter = true
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
          conf.linter[i].stdin and { 'TextChanged', 'InsertLeave', 'BufWritePost' }
            or { 'BufWritePost' }
        )
      end
    end
  end
end

return {
  setup = setup,
}
