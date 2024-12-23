local fn, health = vim.fn, vim.health
local ok, error, info = health.ok, health.error, health.info
local filetype = require('guard.filetype')
local util = require('guard.util')
local events = require('guard.events')
local M = {}

local function executable_check()
  local checked = {}
  for _, item in pairs(filetype) do
    for _, conf in ipairs(item.formatter or {}) do
      if conf.cmd and not vim.tbl_contains(checked, conf.cmd) then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          error(conf.cmd .. ' not found')
        end
        table.insert(checked, conf.cmd)
      end
    end

    for _, conf in ipairs(item.linter or {}) do
      if conf.cmd and not vim.tbl_contains(checked, conf.cmd) then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          error(conf.cmd .. ' not found')
        end
        table.insert(checked, conf.cmd)
      end
    end
  end
  if pcall(require, 'mason') then
    health.warn(
      'It seems that mason.nvim is installed,'
        .. 'in which case checkhealth may be inaccurate.'
        .. ' Please add your mason bin path to PATH to avoid potential issues.'
    )
  end
end

local function dump_settings()
  ok(('fmt_on_save: %s'):format(util.getopt('fmt_on_save')))
  ok(('lsp_as_default_formatter: %s'):format(util.getopt('lsp_as_default_formatter')))
  ok(('save_on_fmt: %s'):format(util.getopt('save_on_fmt')))
end

local function dump_tools(buf)
  local fmtau = events.get_format_autocmds(buf)
  local lintau = events.get_lint_autocmds(buf)
  local ft = vim.bo[buf].ft

  ok(('Current buffer has filetype %s:'):format(ft))
  info(('%s formatter autocmds attached'):format(#fmtau))
  info(('%s linter autocmds attached'):format(#lintau))

  local conf = filetype[ft] or {}
  local formatters = conf.formatter or {}
  local linters = conf.linter or {}

  if #formatters > 0 then
    info('formatters:')
    vim.iter(formatters):map(vim.inspect):each(info)
  end

  if #linters > 0 then
    info('formatters:')
    vim.iter(linters):map(vim.inspect):each(info)
  end
end

-- TODO: add custom autocmds info
M.check = function()
  health.start('Executable check')
  executable_check()

  health.start('Settings')
  dump_settings()

  local orig_bufnr = vim.fn.bufnr('#')
  if not vim.api.nvim_buf_is_valid(orig_bufnr) then
    return
  end
  health.start(('Tools registered for current buffer (bufnr %s)'):format(orig_bufnr))
  dump_tools(orig_bufnr)
end

return M
