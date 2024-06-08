local M = {}

-- @return table | string
function M.transform(cmd, cwd, env, lines)
  local handle = vim.system(cmd, {
    stdin = true,
    cwd = cwd,
    env = env,
  })
  -- write to stdin and close it
  handle:write(lines)
  handle:write(nil)
  local result = handle:wait()
  if result.code ~= 0 and #result.stderr > 0 then
    -- error
    return result
  end
  return result.stdout
end

return M
