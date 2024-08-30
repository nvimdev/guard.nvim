---@diagnostic disable: undefined-field, undefined-global
local api = vim.api
local equal = assert.equal
local ft = require('guard.filetype')

describe('settings module', function()
  local bufnr
  before_each(function()
    for k, _ in pairs(ft) do
      ft[k] = nil
    end

    bufnr = api.nvim_create_buf(true, false)
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    vim.cmd('silent! write! /tmp/fmt_spec_test.lua')
  end)

  it('change settings after setting formatter works', function()
    -- defaults to fmt on save
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    vim.cmd('write')
    vim.wait(500)
    equal({ [[local a = 'test']] }, api.nvim_buf_get_lines(bufnr, 0, -1, false))

    -- change settings
    vim.g.guard_config = {
      fmt_on_save = false,
    }
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    require('guard.format').do_fmt(bufnr)
    equal({
      'local a',
      '          = "test"',
    }, api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it('changing settings before setting formatter works', function()
    vim.g.guard_config = { fmt_on_save = false }
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    vim.cmd('write')
    vim.wait(500)
    equal({
      'local a',
      '          = "test"',
    }, api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)
end)
