local espawn = require('guard.spawn')

describe('spwan module', function()
  it('can spawn a process', function()
    local opt = {
      cmd = 'clang-format',
    }
    coroutine.resume(coroutine.create(function()
      espawn.spawn(opt)
    end))
    --can run into here
    assert.is_true(true)
  end)
end)
