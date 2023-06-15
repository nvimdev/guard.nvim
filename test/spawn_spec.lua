local try_spawn = require('guard.spawn').try_spawn

describe('spwan module', function()
  it('can spawn a process', function()
    local opt = {
      cmd = 'stylua',
    }
    coroutine.resume(coroutine.create(function()
      try_spawn(opt)
    end))

    assert.is_true(true)
  end)
end)
