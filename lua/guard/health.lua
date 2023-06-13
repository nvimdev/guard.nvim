local fn, health = vim.fn, vim.health
local filetype = require('guard.filetype')
local M = {}

local function executable_check()
  for _, item in pairs(filetype) do
    for _, conf in ipairs(item.format or {}) do
      if type(conf) == 'table' then
        if fn.executable(conf.cmd) == 1 then
          health.ok(conf.cmd .. ' found')
        else
          health.error(conf.cmd .. ' not found')
        end
      elseif type(conf) == 'string' then
        local builint = require('guard.tools.formatter')
        if builint[conf] then
          if fn.executable(builint[conf].cmd) == 1 then
            health.ok(builint[conf].cmd .. ' found')
          else
            health.error(builint[conf].cmd .. ' found')
          end
        else
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
