---@diagnostic disable: undefined-field, undefined-global
local util = require('guard.util')
local same = assert.are.same
describe('util module', function()
  it('can copy tool configs', function()
    local original = {
      cmd = 'stylua',
      args = { '-' },
      stdin = true,
    }
    same(util.toolcopy(nil), nil)
    local copy = util.toolcopy(original)
    assert(copy)
    same(copy, original)
    original.cmd = 'sylua'
    same(copy.cmd, 'stylua')
    original = nil
    same(copy.args, { '-' })
  end)

  it('can eval function in tables', function()
    local xs = {
      { cmd = 'foo' },
      function()
        return { cmd = 'bar' }
      end,
    }
    same(util.eval(xs), {
      { cmd = 'foo' },
      { cmd = 'bar' },
    })
  end)
end)
