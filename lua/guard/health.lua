local fn, health = vim.fn, vim.health
local filetype = require('guard.filetype')
local start = vim.version().minor >= 10 and health.start or health.report_start
local ok = vim.version().minor >= 10 and health.ok or health.report_ok
local health_error = vim.version().minor >= 10 and health.error or health.report_error
local M = {}

local function executable_check()
  for _, item in pairs(filetype) do
    for _, conf in ipairs(item.format or {}) do
      if type(conf) == 'table' and conf.cmd then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          health_error(conf.cmd .. ' not found')
        end
      elseif type(conf) == 'string' then
        local entry = require('guard.tools.formatter')
        if entry[conf] and entry[conf].cmd then
          if fn.executable(entry[conf].cmd) == 1 then
            ok(entry[conf].cmd .. ' found')
          else
            health_error(entry[conf].cmd .. ' found')
          end
        elseif not entry[conf] or not entry[conf].fn then
          health_error('this config not exist ' .. conf)
        end
      else
        health_error('wrong type of ' .. conf)
      end
    end

    for _, conf in ipairs(item.linter or {}) do
      if type(conf) == 'table' then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          health_error(conf.cmd .. ' not found')
        end
      elseif type(conf) == 'string' then
        local entry = require('guard.tools.linter.' .. conf)
        if entry then
          if fn.executable(entry.cmd) == 1 then
            ok(entry.cmd .. ' found')
          else
            health_error(entry.cmd .. ' found')
          end
        else
          health_error('this executable not exist ' .. conf)
        end
      else
        health_error('wrong type of ' .. conf)
      end
    end
  end
end

M.check = function()
  start('Executable check')
  executable_check()
end

return M
