local api = vim.api
local group = api.nvim_create_augroup('Guard', { clear = true })
local fts_config = require('guard.filetype')
local util = require('guard.util')

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

local function attach_to(bufnr)
  api.nvim_create_autocmd('BufWritePre', {
    group = group,
    buffer = bufnr,
    callback = function()
      require('guard.format').do_fmt(bufnr)
    end,
  })
end

local function register_event(pattern)
  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = pattern,
    callback = function(args)
      attach_to(args.buf)
    end,
    desc = 'guard',
  })
end

local function create_cmd()
  api.nvim_create_user_command('GuardDisable', function(opts)
    if #opts.fargs == 0 then
      pcall(api.nvim_del_augroup_by_id, group)
      return
    end
    local arg = opts.args
    local _, bufnr = pcall(tonumber, arg)
    if bufnr then
      local _, data = pcall(api.nvim_get_autocmds, { group = group, event = 'BufWritePre', buffer = bufnr })
      if not vim.tbl_isempty(data) then
        api.nvim_del_autocmd(data[1].id)
      end
    else
      local _, listener = pcall(api.nvim_get_autocmds, { group = group, event = 'FileType', pattern = arg })
      if not vim.tbl_isempty(listener) then
        api.nvim_del_autocmd(listener[1].id)
      end
      local _, aus = pcall(api.nvim_get_autocmds, { group = group, event = 'BufWritePre' })
      for _, au in ipairs(aus) do
        if vim.bo[au].ft == arg then
          api.nvim_del_autocmd(au.id)
        end
      end
    end
  end, { nargs = '?' })

  api.nvim_create_user_command('GuardEnable', function(opts)
    if #opts.fargs == 0 then
      local ok, _ = pcall(vim.api.nvim_get_autocmds, { group = group })
      if not ok then
        register_event(get_fts_keys())
      end
      return
    end
    local arg = opts.args
    local _, bufnr = pcall(tonumber, arg)
    if bufnr then
      local data = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = bufnr })
      if vim.tbl_isempty(data) then
        attach_to(bufnr)
      end
    else
      local listener = api.nvim_get_autocmds({ group = group, event = 'FileType', pattern = arg })
      if vim.tbl_isempty(listener) then
        register_event(arg)
      end
    end
  end, { nargs = '?' })
end

local function setup(opt)
  opt = opt or {
    fmt_on_save = true,
    lsp_as_default_formatter = false,
  }

  parse_setup_cfg(opt.ft)
  create_cmd()

  if opt.fmt_on_save then
    register_event(get_fts_keys())
  end

  if opt.lsp_as_default_formatter then
    api.nvim_create_autocmd('LspAttach', {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        ---@diagnostic disable-next-line: need-check-nil
        if not client.supports_method('textDocument/formatting') then
          return
        end
        local fthandler = require('guard.filetype')
        if fthandler[vim.bo[args.buf].filetype] and fthandler[vim.bo[args.buf].filetype].fmt then
          table.insert(fthandler[vim.bo[args.buf]], 1, 'lsp')
        else
          fthandler(vim.bo[args.buf].filetype):fmt('lsp')
        end
      end,
    })
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
