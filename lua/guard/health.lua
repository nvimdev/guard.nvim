local fn, health = vim.fn, vim.health
local filetype = require('guard.filetype')
local M = {}

local function executable_check()
  for _, item in pairs(filetype) do
    for _, conf in ipairs(item.format or {}) do
      if type(conf) == 'table' and conf.cmd then
        if fn.executable(conf.cmd) == 1 then
          health.ok(conf.cmd .. ' found')
        else
          health.error(conf.cmd .. ' not found')
        end
      elseif type(conf) == 'string' then
        local entry = require('guard.tools.formatter')
        if entry[conf] and entry[conf].cmd then
          if fn.executable(entry[conf].cmd) == 1 then
            health.ok(entry[conf].cmd .. ' found')
          else
            health.error(entry[conf].cmd .. ' found')
          end
        elseif not entry[conf].fn then
          health.error('this conf not exist ' .. conf)
        end
      else
        health.error('wrong type of ' .. conf)
      end
    end

    for _, conf in ipairs(item.linter or {}) do
      if type(conf) == 'table' then
        if fn.executable(conf.cmd) == 1 then
          health.ok(conf.cmd .. ' found')
        else
          health.error(conf.cmd .. ' not found')
        end
      elseif type(conf) == 'string' then
        local entry = require('guard.tools.linter.' .. conf)
        if entry then
          if fn.executable(entry.cmd) == 1 then
            health.ok(entry.cmd .. ' found')
          else
            health.error(entry.cmd .. ' found')
          end
        else
          health.error('this executable not exist ' .. conf)
        end
      else
        health.error('wrong type of ' .. conf)
      end
    end
  end
end

M.check = function()
  health.start('Executable check')
  executable_check()
end

return M
