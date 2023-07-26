local api = vim.api
local group = api.nvim_create_augroup('Guard', { clear = true })
local fts_config = require('guard.filetype')
local util = require('guard.util')
local blacklist = {
  ft = {},
  buf = {},
}

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
local fts = get_fts_keys()

local function register_event()
  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = fts,
    callback = function(args)
      api.nvim_create_autocmd('BufWritePre', {
        group = group,
        buffer = args.buf,
        callback = function()
          local bufnr = api.nvim_get_current_buf()
          local ft = vim.bo[bufnr].ft
          if not (vim.tbl_contains(blacklist.buf, bufnr) or vim.tbl_contains(blacklist.ft, ft)) then
            require('guard.format').do_fmt(args.buf)
          end
        end,
      })
    end,
    desc = 'guard',
  })

  api.nvim_create_user_command('GuardDisable', function(opts)
    if #opts.fargs == 0 then
      pcall(api.nvim_del_augroup_by_id, group)
      return
    end
    local arg = opts.args
    local _, bufnr = pcall(tonumber, arg)
    if bufnr and not vim.tbl_contains(blacklist.buf) then
      if bufnr == 0 then
        bufnr = api.nvim_get_current_buf()
      end
      table.insert(blacklist.buf, bufnr)
    else
      if not vim.tbl_contains(blacklist.ft, arg) then
        table.insert(blacklist.ft, arg)
      end
    end
  end, { nargs = '?' })

  api.nvim_create_user_command('GuardEnable', function(opts)
    if #opts.fargs == 0 then
      local au = vim.api.nvim_get_autocmds({ group = group, })
      if not au or vim.tbl_isempty(au) then
        register_event()
      end
      return
    end
    local arg = opts.args
    local _, bufnr = pcall(tonumber, arg)
    if bufnr then
      if bufnr == 0 then
        bufnr = api.nvim_get_current_buf()
      end
      if vim.tbl_contains(blacklist.buf, bufnr) then
        blacklist.buf = vim.tbl_filter(function(v) return v ~= bufnr end, blacklist.buf)
      end
    else
      if vim.tbl_contains(blacklist.ft, arg) then
        blacklist.ft = vim.tbl_filter(function(v) return v ~= arg end, blacklist.ft)
      end
    end
  end, { nargs = '?' })
end

local function setup(opt)
  opt = opt or {
    fmt_on_save = true,
  }

  parse_setup_cfg(opt.ft)

  if opt.fmt_on_save then
    register_event()
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
