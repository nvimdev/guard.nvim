local util = require('guard.util')
local M = {}

local function get_tool(tool_type, tool_name)
  if tool_name == 'lsp' then
    return { fn = require('guard.lsp').format }
  end
  local ok, tbl = pcall(require, 'guard-collection.' .. tool_type)
  if not ok then
    vim.notify(
      ('[Guard]: "%s": needs nvimdev/guard-collection to access builtin configuration'):format(
        tool_name
      ),
      4
    )
    return {}
  end
  if not tbl[tool_name] then
    vim.notify(('[Guard]: %s %s has no builtin configuration'):format(tool_type, tool_name), 4)
    return {}
  end
  return tbl[tool_name]
end
---@return FmtConfig|LintConfig
local function try_as(tool_type, config)
  if type(config) == 'function' then
    return config
  end
  if type(config) == 'table' then
    return config
  else
    return get_tool(tool_type, config)
  end
end
---@param val any
---@param expected string[]
---@return boolean
local function check_type(val, expected)
  if not vim.tbl_contains(expected, type(val)) then
    vim.notify(
      ('[guard]: %s is %s, expected %s'):format(
        vim.inspect(val),
        type(val),
        table.concat(expected, '/')
      )
    )
    return false
  end
  return true
end

local function box(ft)
  local current
  local tbl = {}
  local ft_tbl = ft:find(',') and vim.split(ft, ',') or { ft }
  tbl.__index = tbl

  function tbl:ft()
    return ft_tbl
  end

  function tbl:fmt(config)
    if not check_type(config, { 'table', 'string', 'function' }) then
      return
    end
    current = 'formatter'
    self.formatter = {
      util.toolcopy(try_as('formatter', config)),
    }
    local events = require('guard.events')
    for _, it in ipairs(self:ft()) do
      if it ~= ft then
        M[it] = box(it)
        M[it].formatter = self.formatter
      end

      if config and config.events then
        -- use user's custom events
        events.attach_custom(it, config.events)
      else
        events.fmt_watch_ft(it, self.formatter)
        events.fmt_attach_to_existing(it)
      end
    end
    return self
  end

  function tbl:lint(config)
    if not check_type(config, { 'table', 'string', 'function' }) then
      return
    end
    current = 'linter'
    self.linter = {
      util.toolcopy(try_as('linter', config)),
    }
    local events = require('guard.events')
    local evs = util.linter_events(config)
    for _, it in ipairs(self:ft()) do
      if it ~= ft then
        M[it] = box(it)
        M[it].linter = self.linter
      end
      events.lint_watch_ft(it, evs)
    end
    return self
  end

  function tbl:append(config)
    if not check_type(config, { 'table', 'string', 'function' }) then
      return
    end
    self[current][#self[current] + 1] = try_as(current, config)
    return self
  end

  function tbl:extra(...)
    local tool = self[current][#self[current]]
    tool.args = vim.list_extend({ ... }, tool.args or {})
    return self
  end

  function tbl:env(env)
    if not check_type(env, { 'table' }) then
      return
    end
    if vim.tbl_count(env) == 0 then
      return self
    end
    local tool = self[current][#self[current]]
    tool.env = {}
    ---@diagnostic disable-next-line: undefined-field
    env = vim.tbl_extend('force', vim.uv.os_environ(), env or {})
    for k, v in pairs(env) do
      tool.env[#tool.env + 1] = ('%s=%s'):format(k, tostring(v))
    end
    return self
  end

  function tbl:key_alias(key)
    local _t = {
      ['lint'] = function()
        self.linter = {}
        return self.linter
      end,
      ['fmt'] = function()
        self.formatter = {}
        return self.formatter
      end,
    }
    return _t[key]()
  end

  function tbl:register(key, cfg)
    vim.validate({
      key = {
        key,
        function(val)
          local available = { 'lint', 'fmt' }
          return vim.tbl_contains(available, val)
        end,
      },
    })
    local target = self:key_alias(key)
    local tool_type = key == 'fmt' and 'formatter' or 'linter'
    for _, item in ipairs(cfg) do
      target[#target + 1] = util.toolcopy(try_as(tool_type, item))
    end
  end

  return setmetatable({}, tbl)
end

return setmetatable(M, {
  __call = function(_self, ft)
    if not rawget(_self, ft) then
      rawset(_self, ft, box(ft))
    end
    return _self[ft]
  end,
})
