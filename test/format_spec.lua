local api = vim.api
local equal = assert.equal
local ft = require('guard.filetype')
ft('lua'):fmt('stylua')
require('guard').setup({})

describe('format module', function()
  local bufnr
  before_each(function()
    bufnr = api.nvim_create_buf(true, false)
  end)

  it('can format with stylua', function()
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
    vim.cmd('GuardFmt')
    vim.wait(500)
    local line = api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
    equal([[local a = 'test']], line)
  end)
end)
