local util = require('guard.util')
local ft_handler = require('guard.filetype')
local events = require('guard.events')

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
  vim.tbl_map(function(key)
    if key:find(',') then
      local t = vim.split(key, ',')
      for _, item in ipairs(t) do
        ft_handler[item] = vim.deepcopy(ft_handler[key])
      end
      ft_handler[key] = nil
    end
  end, keys)
end

local function setup(opt)
  opt = vim.tbl_extend('force', {
    fmt_on_save = true,
    lsp_as_default_formatter = false,
  }, opt or {})

  register_cfg_by_table(opt.ft)
  resolve_multi_ft()

  if opt.lsp_as_default_formatter then
    events.create_lspattach_autocmd()
  end

  local lint = require('guard.lint')
  for ft, conf in pairs(ft_handler) do
    local lint_events = { 'BufWritePost', 'BufEnter' }

    if conf.formatter and opt.fmt_on_save then
      events.watch_ft(ft)
      lint_events[1] = 'User GuardFmt'
    end

    if conf.linter then
      for i, _ in ipairs(conf.linter) do
        if conf.linter[i].stdin then
          table.insert(lint_events, 'TextChanged')
          table.insert(lint_events, 'InsertLeave')
        end
        lint.register_lint(ft, lint_events)
      end
    end
  end
end

return {
  setup = setup,
}
