---@diagnostic disable: undefined-field, undefined-global
vim.opt_global.swapfile = false
local api = vim.api
local same = assert.are.same
local ft = require('guard.filetype')
local util = require('guard.util')
local gapi = require('guard.api')
local lint = require('guard.lint')
local ns = api.nvim_get_namespaces()['Guard']
local vd = vim.diagnostic

describe('settings', function()
  local bufnr
  local ill_lua = {
    'local a',
    '          =42',
  }
  local mock_linter_regex = {
    fn = function()
      return '/tmp/lint_spec_test.lua:1:1: warning: Very important error message [error code 114514]'
    end,
    parse = lint.from_regex({
      source = 'mock_linter_regex',
      regex = ':(%d+):(%d+):%s+(%w+):%s+(.-)%s+%[(.-)%]',
      groups = { 'lnum', 'col', 'severity', 'message', 'code' },
      offset = 0,
      severities = {
        information = lint.severities.info,
        hint = lint.severities.info,
        note = lint.severities.style,
      },
    }),
  }
  before_each(function()
    if bufnr then
      vim.cmd('bdelete! ' .. bufnr)
    end
    bufnr = api.nvim_create_buf(true, false)
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    vim.cmd('noautocmd silent! write! /tmp/settings_spec_test.lua')
    vim.cmd('silent! edit!')
    vim.g.guard_config = nil
    vim.iter(api.nvim_get_autocmds({ group = 'Guard' })):each(function(it)
      api.nvim_del_autocmd(it.id)
    end)
  end)

  it('can override fmt_on_save before setting up formatter', function()
    same(true, util.getopt('fmt_on_save'))
    vim.g.guard_config = { fmt_on_save = false }
    same(false, util.getopt('fmt_on_save'))

    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, ill_lua)
    vim.cmd('silent! write')
    vim.wait(500)
    same({
      'local a',
      '          =42',
    }, api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it('can override fmt_on_save after setting up formatter', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, ill_lua)
    same(true, util.getopt('fmt_on_save'))
    vim.cmd('silent! write')
    vim.wait(500)
    same({
      'local a = 42',
    }, api.nvim_buf_get_lines(bufnr, 0, -1, false))

    vim.g.guard_config = { fmt_on_save = false }

    same(false, util.getopt('fmt_on_save'))
    api.nvim_buf_set_lines(bufnr, 0, -1, false, ill_lua)
    vim.cmd('silent! write')
    vim.wait(500)
    same(ill_lua, api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it('can override save_on_fmt before setting up formatter', function()
    same(true, util.getopt('save_on_fmt'))
    vim.g.guard_config = { save_on_fmt = false }
    same(false, util.getopt('save_on_fmt'))

    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, ill_lua)
    vim.cmd('silent! write')
    vim.wait(100)
    gapi.fmt()
    vim.wait(500)
    same(true, vim.bo[bufnr].modified)
  end)

  it('can override save_on_fmt after setting up formatter', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, ill_lua)
    same(true, util.getopt('save_on_fmt'))
    gapi.fmt()
    vim.wait(500)
    same(false, vim.bo[bufnr].modified)

    vim.g.guard_config = { save_on_fmt = false }
    same(false, util.getopt('save_on_fmt'))

    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '      =42',
    })
    vim.cmd('silent! write')
    vim.wait(100)
    gapi.fmt()
    vim.wait(500)
    same(true, vim.bo[bufnr].modified)

    api.nvim_buf_set_lines(bufnr, 0, -1, false, ill_lua)
    gapi.fmt()
    vim.wait(500)
    same(true, vim.bo[bufnr].modified)
  end)

  it('can change auto_lint option to control lint behaviour', function()
    ft('*'):lint(mock_linter_regex)

    same(true, util.getopt('auto_lint'))
    vim.cmd('silent! write!')
    vim.wait(500)
    same({
      {
        source = 'mock_linter_regex',
        bufnr = bufnr,
        col = 1,
        end_col = 1,
        lnum = 1,
        end_lnum = 1,
        message = 'Very important error message[error code 114514]',
        namespace = ns,
        severity = 2,
      },
    }, vd.get())

    vim.g.guard_config = { auto_lint = false }
    same(false, util.getopt('auto_lint'))
    vd.reset(ns)
    vim.cmd('silent! write!')
    vim.wait(500)
    same({}, vd.get())
  end)
end)
