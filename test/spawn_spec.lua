---@diagnostic disable: undefined-field, undefined-global
local spawn = require('guard.spawn')
local same = assert.are.same

describe('spawn module', function()
  it('can spawn executables with stdin access', function()
    coroutine.resume(coroutine.create(function()
      local result = spawn.transform({ 'tac', '-s', '  ' }, {
        stdin = true,
      }, 'test1  test2  test3  ')
      same(result, 'test3  test2  test1  ')
    end))
  end)
end)
