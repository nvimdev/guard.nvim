local util = require('guard.util')
local ft_handler = require('guard.filetype')
local events = require('guard.events')

local config = {
  opts = nil,
}

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
      local src = ft_handler[key]
      for _, item in ipairs(vim.split(key, ',')) do
        ft_handler[item] = {}
        ft_handler[item].formatter = src.formatter and vim.tbl_map(util.toolcopy, src.formatter)
        ft_handler[item].linter = src.linter and vim.tbl_map(util.toolcopy, src.linter)
      end
      ft_handler[key] = nil
    end
  end, keys)
end

local function setup(opt)
  config.opts = vim.tbl_extend('force', {
    fmt_on_save = true,
    lsp_as_default_formatter = false,
    save_on_fmt = true,
  }, opt or {})

  register_cfg_by_table(config.opts.ft)
  resolve_multi_ft()

  if config.opts.lsp_as_default_formatter then
    events.create_lspattach_autocmd(config.opts.fmt_on_save)
  end

  for ft, conf in pairs(ft_handler) do
    local lint_events = { 'BufWritePost', 'BufEnter' }

    if conf.formatter and config.opts.fmt_on_save then
      events.watch_ft(ft)
      lint_events[1] = 'User GuardFmt'
    end

    if conf.linter then
      for i, _ in ipairs(conf.linter) do
        if conf.linter[i].stdin then
          table.insert(lint_events, 'TextChanged')
          table.insert(lint_events, 'InsertLeave')
        end
        events.register_lint(ft, lint_events)
      end
    end
  end
end

return {
  setup = setup,
  config = config,
}
