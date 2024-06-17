---@diagnostic disable: undefined-field, undefined-global
local ft = require('guard.filetype')
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
    })
    same({
      formatter = {
        { cmd = 'clang-format' },
      },
    }, ft.c)
  end)

  it('can register fmt with many configs', function()
    ft('python'):fmt({
      cmd = 'tool1',
      timeout = 1000,
    }):append({
      cmd = 'tool2',
      timeout = 1000,
    })
    same({
      formatter = {
        { cmd = 'tool1', timeout = 1000 },
        { cmd = 'tool2', timeout = 1000 },
      },
    }, ft.python)
  end)

  it('can register filetype with lint config', function()
    ft('python'):lint({
      cmd = 'black',
    })
    same({
      linter = {
        { cmd = 'black' },
      },
    }, ft.python)
  end)

  it('can register filetype with many lint config', function()
    ft('python'):lint({
      cmd = 'black',
      timeout = 1000,
    }):append({
      cmd = 'other',
      timeout = 1000,
    })
    same({
      linter = {
        { cmd = 'black', timeout = 1000 },
        { cmd = 'other', timeout = 1000 },
      },
    }, ft.python)
  end)

  it('can register format and lint ', function()
    local py = ft('python')
    py:fmt({ cmd = 'first', timeout = 1000 }):append({ cmd = 'second' }):append({ cmd = 'third' })
    py:lint({ cmd = 'first' }):append({ cmd = 'second' }):append({ cmd = 'third' })
    same({
      formatter = {
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
      formatter = {
        { cmd = 'clang-format' },
      },
    }, ft.c)
    same({
      formatter = {
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
      formatter = { { cmd = 'prettier', args = { 'some', 'args' } } },
    }, ft.javascript)
    same({
      formatter = { { cmd = 'prettier', args = { 'some', 'args' } } },
    }, ft.javascriptreact)
  end)

  it('can add extra command arguments', function()
    ft('c')
      :fmt({
        cmd = 'clang-format',
        args = { '--style=Mozilla' },
        stdin = true,
      })
      :extra('--verbose')
      :lint({
        cmd = 'clang-tidy',
        args = { '--quiet' },
        parse = function() end,
      })
      :extra('--fix')

    same({
      cmd = 'clang-format',
      args = { '--verbose', '--style=Mozilla' },
      stdin = true,
    }, ft.c.formatter[1])

    same({ '--fix', '--quiet' }, ft.c.linter[1].args)
  end)
end)
