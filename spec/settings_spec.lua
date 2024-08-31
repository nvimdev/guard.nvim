---@diagnostic disable: undefined-field, undefined-global
vim.opt_global.swapfile = false
local api = vim.api
local same = assert.are.same
local ft = require('guard.filetype')
local util = require('guard.util')

describe('settings', function()
  local bufnr
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

    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
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

    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    same(true, util.getopt('fmt_on_save'))
    vim.cmd('silent! write')
    vim.wait(500)
    same({
      'local a = 42',
    }, api.nvim_buf_get_lines(bufnr, 0, -1, false))

    vim.g.guard_config = { fmt_on_save = false }

    same(false, util.getopt('fmt_on_save'))
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    vim.cmd('silent! write')
    vim.wait(500)
    same({
      'local a',
      '          =42',
    }, api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it('can override save_on_fmt before setting up formatter', function()
    same(true, util.getopt('fmt_on_save'))
    vim.g.guard_config = { save_on_fmt = false }
    same(false, util.getopt('fmt_on_save'))

    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    vim.cmd('Guard fmt')
    vim.wait(500)
    same(true, vim.bo.modified)
  end)

  it('can override save_on_fmt after setting up formatter', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    same(true, util.getopt('save_on_fmt'))
    vim.cmd('Guard fmt')
    vim.wait(500)
    same(false, vim.bo.modified)

    vim.g.guard_config = { save_on_fmt = false }

    same(false, util.getopt('save_on_fmt'))
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    vim.cmd('Guard fmt')
    vim.wait(500)
    same({
      'local a = 42',
    }, api.nvim_buf_get_lines(bufnr, 0, -1, false))
    same(true, vim.bo.modified)
  end)
end)
