local M = {}

-- @return table | string
function M.transform(cmd, cwd, env, lines)
  local co = assert(coroutine.running())
  local handle = vim.system(cmd, {
    stdin = true,
    cwd = cwd,
    env = env,
  }, function(result)
    if result.code ~= 0 and #result.stderr > 0 then
      -- error
      coroutine.resume(co, result)
    else
      coroutine.resume(co, result.stdout)
    end
  end)
  -- write to stdin and close it
  handle:write(lines)
  handle:write(nil)
  return coroutine.yield()
end

return M
