---@diagnostic disable: undefined-field, undefined-global
local api = vim.api
local ft = require('guard.filetype')
local same = assert.are.same

ft('lua'):fmt({
  cmd = 'stylua',
  args = { '-' },
  stdin = true,
})

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
        same(opts.data.using[1], {
          cmd = 'stylua',
          args = { '-' },
          stdin = true,
        })
      end
    end)
    require('guard.format').do_fmt(bufnr)
    vim.wait(500)
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
    same(api.nvim_buf_get_lines(bufnr, 0, -1, false), { '' })
  end)
end)
