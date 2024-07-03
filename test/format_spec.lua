---@diagnostic disable: undefined-field, undefined-global
local api = vim.api
local equal = assert.equal
local ft = require('guard.filetype')

describe('format module', function()
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

  it('can format with single formatter', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })
    require('guard').setup()
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    local line = api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
    equal([[local a = 'test']], line)
  end)

  it('can format with multiple formatters', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    }):append({
      cmd = 'tac',
      args = { '-s', ' ' },
      stdin = true,
    })
    require('guard').setup()
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.are.same({ "'test'", '= a local ' }, lines)
  end)

  it('can format with function', function()
    ft('lua'):fmt({
      fn = function(buf, range, acc)
        return table.concat(vim.split(acc, '\n'), '') .. vim.inspect(range)
      end,
    })
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.are.same({ 'local a          = "test"nil' }, lines)
  end)
end)
