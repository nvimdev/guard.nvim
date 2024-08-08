require('plugin.guard')
vim.opt_global.swapfile = false
local api = vim.api
local same = assert.are.same

describe('commands', function()
  require('guard.filetype')('lua'):fmt({
    cmd = 'stylua',
    args = { '-' },
    stdin = true,
  })
  require('guard').setup()

  local bufnr
  before_each(function()
    if bufnr then
      vim.cmd('bdelete! ' .. bufnr)
    end
    bufnr = api.nvim_create_buf(true, false)
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    vim.cmd('noautocmd silent! write! /tmp/cmd_spec_test.lua')
    vim.cmd('silent! edit!')
  end)

  it('can call formatting manually', function()
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    vim.cmd('GuardFmt')
    vim.wait(500)
    same(api.nvim_buf_get_lines(bufnr, 0, -1, false), { 'local a = 42' })
  end)

  it('can disable auto format and enable again', function()
    -- default
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    vim.cmd('silent! write')
    vim.wait(500)
    same(api.nvim_buf_get_lines(bufnr, 0, -1, false), { 'local a = 42' })

    -- disable
    vim.cmd('GuardDisable')
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

    -- enable
    vim.cmd('GuardEnable')
    -- make changes to trigger format
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          =42',
    })
    vim.cmd('silent! write')
    vim.wait(500)
    same(api.nvim_buf_get_lines(bufnr, 0, -1, false), { 'local a = 42' })
  end)
end)
