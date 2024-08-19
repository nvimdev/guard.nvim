local fn, health = vim.fn, vim.health
local filetype = require('guard.filetype')
local ok, error = health.ok, health.error
local M = {}

local function executable_check()
  local checked = {}
  for _, item in pairs(filetype) do
    for _, conf in ipairs(item.formatter or {}) do
      if conf.cmd and not vim.tbl_contains(checked, conf.cmd) then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          error(conf.cmd .. ' not found')
        end
        table.insert(checked, conf.cmd)
      end
    end

    for _, conf in ipairs(item.linter or {}) do
      if conf.cmd and not vim.tbl_contains(checked, conf.cmd) then
        if fn.executable(conf.cmd) == 1 then
          ok(conf.cmd .. ' found')
        else
          error(conf.cmd .. ' not found')
        end
        table.insert(checked, conf.cmd)
      end
    end
    if pcall(require, 'mason') then
      health.warn(
        'It seems that mason.nvim is installed,'
          .. 'in which case checkhealth may be inaccurate.'
          .. ' Please add your mason bin path to PATH to avoid potential issues.'
      )
    end
  end
end

M.check = function()
  health.start('Executable check')
  executable_check()
end

return M
