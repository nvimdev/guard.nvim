local espawn = require('guard.spawn')

describe('spwan module', function()
  it('can spawn a process', function()
    local opt = {
      cmd = 'clang-format',
    }
    local handle = espawn.spawn(opt)
    assert.is_true(type(handle) == 'userdata')
  end)
end)
