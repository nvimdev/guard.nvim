local fn, health = vim.fn, vim.health
local filetype = require('guard.filetype')
local start = vim.version().minor >= 10 and health.start or health.report_start
local ok = vim.version().minor >= 10 and health.ok or health.report_ok
local health_error = vim.version().minor >= 10 and health.error or health.report_error
local M = {}

local function executable_check()
  local checked = {}
  for _, item in pairs(filetype) do
    for _, conf in ipairs(item.format or {}) do
      if not vim.tbl_contains(checked, conf.cmd) then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          health_error(conf.cmd .. ' not found')
        end
        table.insert(checked, conf.cmd)
      end
    end

    for _, conf in ipairs(item.linter or {}) do
      if not vim.tbl_contains(checked, conf.cmd) then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          health_error(conf.cmd .. ' not found')
        end
        table.insert(checked, conf.cmd)
      end
    end
  end
end

M.check = function()
  start('Executable check')
  executable_check()
end

return M
