-- These are considered public API and changing their signature would be a breaking change
local M = {}
local api = vim.api
local events = require('guard.events')

---Format bufnr or current buffer
---@param bufnr number?
function M.fmt(bufnr)
  require('guard.format').do_fmt(bufnr)
end

---Lint bufnr or current buffer
---@param bufnr number?
function M.lint(bufnr)
  require('guard.lint').do_lint(bufnr)
end

---Enable format for bufnr or current buffer
---@param bufnr number?
function M.enable_fmt(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()
  local ft_handler = require('guard.filetype')
  local ft = vim.bo[buf].ft
  local head = vim.tbl_get(ft_handler, ft, 'formatter', 1)
  if type(head) == 'table' and type(head.events) == 'table' then
    events.fmt_attach_custom(ft, head.events)
  else
    events.try_attach_fmt_to_buf(buf)
  end
end

---Disable format for bufnr or current buffer
---@param bufnr number?
function M.disable_fmt(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()
  vim.iter(events.get_format_autocmds(buf)):each(function(x)
    api.nvim_del_autocmd(x)
  end)
  events.user_fmt_autocmds[vim.bo[buf].ft] = {}
end

---Enable lint for bufnr or current buffer
---@param bufnr number?
function M.enable_lint(bufnr)
  local buf = bufnr or api.nvim_get_current_buf()
  local ft = require('guard.filetype')[vim.bo[buf].ft] or {}
  if ft.linter and #ft.linter > 0 then
    events.try_attach_lint_to_buf(
      buf,
      require('guard.util').linter_events(ft.linter[1]),
      vim.bo[buf].ft
    )
  end
end

---Disable format for bufnr or current buffer
---@param bufnr number?
function M.disable_lint(bufnr)
  local aus = events.get_lint_autocmds(bufnr or api.nvim_get_current_buf())
  vim.iter(aus):each(function(au)
    api.nvim_del_autocmd(au.id)
  end)
end

---Show guard info for current buffer
function M.info()
  local util = require('guard.util')
  local buf = api.nvim_get_current_buf()
  local ft = require('guard.filetype')[vim.bo[buf].ft] or {}
  local formatters = ft.formatter or {}
  local linters = ft.linter or {}
  local fmtau = events.get_format_autocmds(buf)
  local lintau = events.get_lint_autocmds(buf)

  util.open_info_win()
  local lines = {
    '# Guard info (press Esc or q to close)',
    '## Settings:',
    ('- `fmt_on_save`: %s'):format(util.getopt('fmt_on_save')),
    ('- `lsp_as_default_formatter`: %s'):format(util.getopt('lsp_as_default_formatter')),
    ('- `save_on_fmt`: %s'):format(util.getopt('save_on_fmt')),
    '',
    ('## Current buffer has filetype %s:'):format(vim.bo[buf].ft),
    ('- %s formatter autocmds attached'):format(#fmtau),
    ('- %s linter autocmds attached'):format(#lintau),
    '- formatters:',
    '',
  }

  if #formatters > 0 then
    vim.list_extend(lines, { '', '```lua' })
    vim.list_extend(
      lines,
      vim
        .iter(formatters)
        :map(function(formatter)
          return vim.split(vim.inspect(formatter), '\n', { trimempty = true })
        end)
        :flatten()
        :totable()
    )
    vim.list_extend(lines, { '```', '' })
  end

  vim.list_extend(lines, { '- linters:' })

  if #linters > 0 then
    vim.list_extend(lines, { '', '```lua' })
    vim.list_extend(
      lines,
      vim
        .iter(linters)
        :map(function(linter)
          return vim.split(vim.inspect(linter), '\n', { trimempty = true })
        end)
        :flatten()
        :totable()
    )
    vim.list_extend(lines, { '```' })
  end

  api.nvim_buf_set_lines(0, 0, -1, true, lines)
  api.nvim_set_option_value('modifiable', false, { buf = 0 })
end

return M
