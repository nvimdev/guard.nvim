---@diagnostic disable: undefined-field, undefined-global
local api = vim.api
local equal = assert.equal
local ft = require('guard.filetype')
ft('lua'):fmt({
  cmd = 'stylua',
  args = { '-' },
  stdin = true,
})
require('guard').setup()

describe('format module', function()
  local bufnr
  before_each(function()
    bufnr = api.nvim_create_buf(true, false)
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    vim.cmd('silent! write! /tmp/fmt_spec_test.lua')
  end)

  it('can format with stylua', function()
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    local line = api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
    equal([[local a = 'test']], line)
  end)
end)
