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
      fn = function(_, range, acc)
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

  it('can format with dynamic formatters', function()
    ft('lua'):fmt(function()
      if vim.g.some_flag_idk then
        return {
          fn = function()
            return 'abc'
          end,
        }
      else
        return {
          fn = function()
            return 'def'
          end,
        }
      end
    end)

    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'foo',
      'bar',
    })
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.are.same({ 'def' }, lines)

    vim.g.some_flag_idk = true

    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.are.same({ 'abc' }, lines)
  end)
end)
