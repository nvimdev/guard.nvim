---@diagnostic disable: undefined-field, undefined-global
local ft = require('guard.filetype')
local same = assert.are.same
vim.g.guard_config = {
  fmt_on_save = true,
  lsp_as_default_formatter = false,
  save_on_fmt = true,
}

describe('filetype module', function()
  before_each(function()
    for k, _ in pairs(ft) do
      ft[k] = nil
    end
  end)

  it('can register filetype with fmt config', function()
    ft('lua'):fmt({
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    })
    same({
      formatter = {
        {
          cmd = 'stylua',
          args = { '-' },
          stdin = true,
        },
      },
    }, ft.lua)
  end)

  it('can register fmt with many configs', function()
    ft('python'):fmt({
      cmd = 'tac',
      timeout = 1000,
    }):append({
      cmd = 'cat',
      timeout = 1000,
    })
    same({
      formatter = {
        { cmd = 'tac', timeout = 1000 },
        { cmd = 'cat', timeout = 1000 },
      },
    }, ft.python)
  end)

  it('can register filetype with lint config', function()
    ft('python'):lint({
      cmd = 'wc',
    })
    same({
      linter = {
        { cmd = 'wc' },
      },
    }, ft.python)
  end)

  it('can register filetype with many lint config', function()
    ft('python'):lint({
      cmd = 'wc',
      timeout = 1000,
    }):append({
      cmd = 'file',
      timeout = 1000,
    })
    same({
      linter = {
        { cmd = 'wc', timeout = 1000 },
        { cmd = 'file', timeout = 1000 },
      },
    }, ft.python)
  end)

  it('can register format and lint ', function()
    local py = ft('python')
    py:fmt({ cmd = 'head' }):append({ cmd = 'cat', timeout = 1000 }):append({ cmd = 'tail' })
    py:lint({ cmd = 'tac' }):append({ cmd = 'wc' }):append({ cmd = 'cat' })
    same({
      formatter = {
        { cmd = 'head' },
        { cmd = 'cat', timeout = 1000 },
        { cmd = 'tail' },
      },
      linter = {
        { cmd = 'tac' },
        { cmd = 'wc' },
        { cmd = 'cat' },
      },
    }, ft.python)
  end)

  it('can register a formatter for multiple filetypes simultaneously', function()
    ft('javascript,javascriptreact'):fmt({
      cmd = 'cat',
      args = { '-v', '-E' },
    })
    require('guard').setup({})
    same({
      formatter = { { cmd = 'cat', args = { '-v', '-E' } } },
    }, ft.javascript)
    same({
      formatter = { { cmd = 'cat', args = { '-v', '-E' } } },
    }, ft.javascriptreact)
  end)

  it('can add extra command arguments', function()
    ft('c')
      :fmt({
        cmd = 'cat',
        args = { '-n' },
        stdin = true,
      })
      :extra('-s')
      :lint({
        cmd = 'wc',
        args = { '-L', '1' },
        parse = function() end,
      })
      :extra('-l')

    same({
      cmd = 'cat',
      args = { '-s', '-n' },
      stdin = true,
    }, ft.c.formatter[1])

    same({ '-l', '-L', '1' }, ft.c.linter[1].args)
  end)

  it('can detect non executable formatters', function()
    assert(not pcall(function()
      ft('c'):fmt({ cmd = 'hjkl' })
    end))
  end)

  it('can detect non executable linters', function()
    assert(not pcall(function()
      ft('c'):lint({ cmd = 'hjkl' })
    end))
  end)
end)
