local api = vim.api
local group = api.nvim_create_augroup('Guard', { clear = true })
local ft_handler = require('guard.filetype')
local util = require('guard.util')

local function attach_to(buf)
  api.nvim_create_autocmd('BufWritePre', {
    group = group,
    buffer = buf,
    callback = function(opt)
      require('guard.format').do_fmt(opt.buf)
    end,
  })
end

local function watch_ft(fts)
  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = fts,
    callback = function(args)
      attach_to(args.buf)
    end,
    desc = 'guard',
  })
end

local function register_cfg_by_table(fts_with_cfg)
  for ft, cfg in pairs(fts_with_cfg or {}) do
    if not vim.tbl_isempty(cfg) then
      local handler = ft_handler(ft)
      local keys = vim.tbl_keys(cfg)
      vim.tbl_map(function(key)
        handler:register(key, util.as_table(cfg[key]))
      end, keys)
    end
  end
end

local function resolve_multi_ft()
  local keys = vim.tbl_keys(ft_handler)
  local retval = {}
  vim.tbl_map(function(key)
    if key:find(',') then
      local t = vim.split(key, ',')
      for _, item in ipairs(t) do
        ft_handler[item] = vim.deepcopy(ft_handler[key])
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

  register_cfg_by_table(opt.ft)
  local parsed = resolve_multi_ft()

  if opt.fmt_on_save then
    watch_ft(parsed)
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
        if fthandler[vim.bo[args.buf].filetype] and fthandler[vim.bo[args.buf].filetype].format then
          table.insert(fthandler[vim.bo[args.buf].filetype].format, 1, 'lsp')
        else
          fthandler(vim.bo[args.buf].filetype):fmt('lsp')
        end

        local ok, au = pcall(api.nvim_get_autocmds, {
              group = 'Guard',
              event = 'FileType',
              pattern = vim.bo[args.buf].filetype,
        })
        if
          opt.fmt_on_save
          and ok
          and #au == 0
        then
          attach_to(args.buf)
        end
      end,
    })
  end

  local lint = require('guard.lint')
  for ft, conf in pairs(ft_handler) do
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
