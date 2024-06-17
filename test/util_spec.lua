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
end)
