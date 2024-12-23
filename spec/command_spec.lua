---@diagnostic disable: undefined-field, undefined-global
require('plugin.guard')
vim.opt_global.swapfile = false
local api = vim.api
local same = assert.are.same
local ft = require('guard.filetype')

describe('commands', function()
  ft('lua'):fmt({
    cmd = 'stylua',
    args = { '-' },
    stdin = true,
  })

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

  local ill_lua = { 'local a', '          =42' }

  local function getlines()
    return api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local function setlines(lines)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  it('can call formatting manually', function()
    setlines(ill_lua)
    vim.cmd('Guard fmt')
    vim.wait(500)
    same(getlines(), { 'local a = 42' })
  end)

  it('can disable auto format and enable again', function()
    -- default
    setlines(ill_lua)
    vim.cmd('silent! write')
    vim.wait(500)
    same(getlines(), { 'local a = 42' })

    -- disable
    vim.cmd('Guard disable-fmt')
    setlines(ill_lua)
    vim.cmd('silent! write')
    vim.wait(500)
    same(getlines(), {
      'local a',
      '          =42',
    })

    -- enable
    vim.cmd('Guard enable-fmt')
    -- make changes to trigger format
    setlines(ill_lua)
    vim.cmd('silent! write')
    vim.wait(500)
    same(getlines(), { 'local a = 42' })
  end)

  it('can disable custom user events', function()
    vim.iter(api.nvim_get_autocmds({ group = require('guard.events').group })):each(function(au)
      api.nvim_del_autocmd(au.id)
    end)

    ft('lua'):fmt({
      fn = function()
        return 'test'
      end,
      events = { { name = 'ColorScheme', opt = { pattern = 'blue' } } },
    })

    setlines(ill_lua)
    vim.cmd('colorscheme blue')
    vim.wait(500)
    same(getlines(), { 'test' })

    -- disable
    vim.cmd('Guard disable-fmt')
    setlines(ill_lua)
    vim.cmd('noautocmd silent! write!')
    vim.cmd('colorscheme vim')
    vim.cmd('colorscheme blue')
    vim.wait(500)
    same(getlines(), ill_lua)

    -- enable
    vim.cmd('Guard enable-fmt')
    vim.cmd('colorscheme vim')
    vim.cmd('colorscheme blue')
    vim.wait(500)
    same(getlines(), { 'test' })
  end)
end)
