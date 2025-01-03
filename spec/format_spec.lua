---@diagnostic disable: undefined-field, undefined-global
local api = vim.api
local same = assert.are.same
local ft = require('guard.filetype')
local gapi = require('guard.api')

describe('format module', function()
  local bufnr
  local ill_lua = {
    'local a',
    '          = "test"',
  }

  before_each(function()
    for k, _ in pairs(ft) do
      ft[k] = nil
    end

    bufnr = api.nvim_create_buf(true, false)
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    vim.cmd('silent! write! /tmp/fmt_spec_test.lua')
  end)

  local function getlines()
    return api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  local function setlines(lines)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end

  it('can format with single formatter', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })
    setlines(ill_lua)
    gapi.fmt()
    vim.wait(500)
    same({ "local a = 'test'" }, getlines())
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
    setlines(ill_lua)
    gapi.fmt()
    vim.wait(500)
    same({ "'test'", '= a local ' }, getlines())
  end)

  it('can format with function', function()
    ft('lua'):fmt({
      fn = function(_, range, acc)
        return table.concat(vim.split(acc, '\n'), '') .. vim.inspect(range)
      end,
    })
    setlines(ill_lua)
    gapi.fmt()
    vim.wait(500)
    same({ 'local a          = "test"nil' }, getlines())
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

    setlines({ 'foo', 'bar' })
    gapi.fmt()
    vim.wait(500)
    local lines = getlines()
    assert.are.same({ 'def' }, lines)

    vim.g.some_flag_idk = true

    gapi.fmt()
    vim.wait(500)
    lines = getlines()
    assert.are.same({ 'abc' }, lines)

    vim.g.some_flag_idk = false

    gapi.fmt()
    vim.wait(500)
    lines = getlines()
    assert.are.same({ 'def' }, lines)
  end)

  it('can format on custom user events', function()
    ft('lua'):fmt({
      fn = function()
        return 'abc'
      end,
      -- I don't know why anyone would do this but hey
      events = { { name = 'ColorScheme', opt = { pattern = 'blue' } } },
    })

    setlines(ill_lua)

    -- should have been overridden
    vim.cmd('silent! write!')
    vim.wait(500)
    same(ill_lua, getlines())

    -- did not match pattern
    vim.cmd('colorscheme vim')
    vim.wait(500)
    same(ill_lua, getlines())

    vim.cmd('colorscheme blue')
    vim.wait(500)
    same({ 'abc' }, getlines())
  end)

  it('tries its best to preserve indent', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })
    setlines({
      'if foo then',
      ' bar  (  )  ',
      'end',
    })
    vim.cmd('2')
    vim.cmd([[silent! norm V:GuardFmt <cr>]])
    same({ 'if foo then', ' bar  (  )  ', 'end' }, getlines())
  end)
end)
