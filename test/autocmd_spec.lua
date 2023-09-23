local api = vim.api
local ft = require('guard.filetype')
ft('lua'):fmt({
  cmd = 'stylua',
  args = { '-' },
  stdin = true,
})
require('guard').setup()

describe('autocmd module', function()
  local bufnr
  local function au(cb)
    api.nvim_create_autocmd('User', {
      pattern = 'GuardFmt',
      group = api.nvim_create_augroup('TestGroup', {}),
      callback = cb,
    })
  end

  before_each(function()
    pcall(api.nvim_del_augroup_by_name, 'TestGroup')
    bufnr = api.nvim_create_buf(true, false)
    vim.bo[bufnr].filetype = 'lua'
    api.nvim_set_current_buf(bufnr)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      'local a',
      '          = "test"',
    })
  end)

  it('can trigger before formatting', function()
    au(function(opts)
      -- pre format au
      if opts.data.status == 'pending' then
        api.nvim_buf_set_lines(bufnr, 0, -1, false, {
          'local a',
          '          = "changed!"',
        })
      end
    end)
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    assert.are.same(api.nvim_buf_get_lines(bufnr, 0, -1, false), { "local a = 'changed!'" })
  end)

  it('can trigger after formatting', function()
    au(function(opts)
      -- post format au
      if opts.data.status == 'done' then
        api.nvim_buf_set_lines(bufnr, 0, -1, false, { '' })
      end
    end)
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
    assert.are.same(api.nvim_buf_get_lines(bufnr, 0, -1, false), { '' })
  end)
end)
