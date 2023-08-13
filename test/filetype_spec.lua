local ft = require('guard.filetype')
---@diagnostic disable-next-line: deprecated
local uv = vim.version().minor >= 10 and vim.uv or vim.loop
local same = assert.are.same

describe('filetype module', function()
  before_each(function()
    for k, _ in pairs(ft) do
      ft[k] = nil
    end
  end)

  it('can register filetype with fmt config', function()
    ft('c'):fmt({
      cmd = 'clang-format',
      lines = { 'test', 'lines' },
    })
    same({
      format = {
        { cmd = 'clang-format', lines = { 'test', 'lines' } },
      },
    }, ft.c)
  end)

  it('can register fmt with many configs', function()
    ft('python'):fmt({
      cmd = 'tool1',
      lines = { 'test' },
      timeout = 1000,
    }):append({
      cmd = 'tool2',
      lines = 'test',
      timeout = 1000,
    })
    same({
      format = {
        { cmd = 'tool1', lines = { 'test' }, timeout = 1000 },
        { cmd = 'tool2', lines = 'test', timeout = 1000 },
      },
    }, ft.python)
  end)

  it('can register filetype with lint config', function()
    ft('python'):lint({
      cmd = 'black',
      lines = { 'test', 'lines' },
    })
    same({
      linter = {
        { cmd = 'black', lines = { 'test', 'lines' } },
      },
    }, ft.python)
  end)

  it('can register filetype with many lint config', function()
    ft('python'):lint({
      cmd = 'black',
      lines = { 'test', 'lines' },
      timeout = 1000,
    }):append({
      cmd = 'other',
      lines = { 'test' },
      timeout = 1000,
    })
    same({
      linter = {
        { cmd = 'black', lines = { 'test', 'lines' }, timeout = 1000 },
        { cmd = 'other', lines = { 'test' }, timeout = 1000 },
      },
    }, ft.python)
  end)

  it('can register format and lint ', function()
    local py = ft('python')
    py:fmt({ cmd = 'first', timeout = 1000 }):append({ cmd = 'second' }):append({ cmd = 'third' })
    py:lint({ cmd = 'first' }):append({ cmd = 'second' }):append({ cmd = 'third' })
    same({
      format = {
        { cmd = 'first', timeout = 1000 },
        { cmd = 'second' },
        { cmd = 'third' },
      },
      linter = {
        { cmd = 'first' },
        { cmd = 'second' },
        { cmd = 'third' },
      },
    }, ft.python)
  end)

  it('can setup filetypes via setup()', function()
    require('guard').setup({
      ft = {
        c = {
          fmt = {
            cmd = 'clang-format',
            lines = { 'test', 'lines' },
          },
        },
        python = {
          fmt = {
            { cmd = 'tool-1' },
            { cmd = 'tool-2' },
          },
          lint = {
            cmd = 'lint_tool_1',
          },
        },
        rust = {
          lint = {
            {
              cmd = 'clippy',
              args = { 'check' },
              stdin = true,
            },
          },
        },
      },
    })
    same({
      format = {
        { cmd = 'clang-format', lines = { 'test', 'lines' } },
      },
    }, ft.c)
    same({
      format = {
        { cmd = 'tool-1' },
        { cmd = 'tool-2' },
      },
      linter = {
        { cmd = 'lint_tool_1' },
      },
    }, ft.python)
    same({
      linter = {
        { cmd = 'clippy', args = { 'check' }, stdin = true },
      },
    }, ft.rust)
  end)

  it('can register a formatter for multiple filetypes simultaneously', function()
    ft('javascript,javascriptreact'):fmt({
      cmd = 'prettier',
      args = { 'some', 'args' },
    })
    require('guard').setup({})
    same({
      format = { { cmd = 'prettier', args = { 'some', 'args' } } },
    }, ft.javascript)
    same({
      format = { { cmd = 'prettier', args = { 'some', 'args' } } },
    }, ft.javascriptreact)
  end)

  it('can add extra command arguments', function()
    ft('c'):fmt('clang-format'):extra('--verbose'):lint('clang-tidy'):extra('--fix')
    same({
      cmd = 'clang-format',
      args = { '--verbose' },
      stdin = true,
    }, require('guard.tools.formatter')['clang-format'])

    same({
      '--fix',
      '--quiet',
    }, require('guard.tools.linter.clang-tidy').args)
  end)
end)
