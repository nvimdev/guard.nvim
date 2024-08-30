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

  it('can override defaults before setting up formatter', function()
    same(util.getopt('fmt_on_save'), true)
    vim.g.guard_config = { fmt_on_save = false }
    same(util.getopt('fmt_on_save'), false)

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
    same(api.nvim_buf_get_lines(bufnr, 0, -1, false), {
      'local a',
      '          =42',
    })
  end)

  it('can override defaults after setting up formatter', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })

    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    same(util.getopt('fmt_on_save'), true)
    vim.cmd('silent! write')
    vim.wait(500)
    same(api.nvim_buf_get_lines(bufnr, 0, -1, false), {
      'local a = 42',
    })

    vim.g.guard_config = { fmt_on_save = false }

    same(util.getopt('fmt_on_save'), false)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    vim.cmd('silent! write')
    vim.wait(500)
    same(api.nvim_buf_get_lines(bufnr, 0, -1, false), {
      'local a',
      '          =42',
    })
  end)
end)
