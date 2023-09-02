local M = {}

local function get_tool(tool_type, tool_name)
  local ok, tbl = pcall(require, 'guard-collection.' .. tool_type)
  if not ok then
    vim.notify(
      ('[Guard]: "%s": needs nvimdev/guard-collection to access builtin configuration'):format(
        tool_name
      ),
      4
    )
    return
  end
  if not tbl[tool_name] then
    vim.notify(('[Guard]: %s %s has no builtin configuration'):format(tool_type, tool_name), 4)
    return
  end
  return tbl[tool_name]
end
local function try_as(tool_type, config)
  return type(config) == 'table' and config or get_tool(tool_type, config)
end

local function box()
  local current
  local tbl = {}
  tbl.__index = tbl

  function tbl:fmt(config)
    vim.validate({
      config = { config, { 'table', 'string' } },
    })
    current = 'format'
    self.format = {
      vim.deepcopy(try_as('formatter', config)),
    }
    return self
  end

  function tbl:lint(config)
    vim.validate({
      config = { config, { 'table', 'string' } },
    })
    current = 'linter'
    self.linter = {
      vim.deepcopy(try_as('linter', config)),
    }
    return self
  end

  function tbl:append(val)
    local tool_type = current == 'format' and 'formatter' or 'linter'
    self[current][#self[current] + 1] = vim.deepcopy(try_as(tool_type, val))
    return self
  end

  function tbl:extra(...)
    local tool = self[current][#self[current]]
    tool.args = vim.list_extend({ ... }, tool.args or {})
    return self
  end

  function tbl:env(env)
    vim.validate({
      env = { env, 'table' },
    })
    if vim.tbl_count(env) == 0 then
      return self
    end
    local tool = self[current][#self[current]]
    tool.env = {}
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
        self.format = {}
        return self.format
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
      target[#target + 1] = vim.deepcopy(try_as(tool_type, item))
    end
  end

  return setmetatable({}, tbl)
end

return setmetatable(M, {
  __call = function(t, ft)
    if not rawget(t, ft) then
      rawset(t, ft, box())
    end
    return t[ft]
  end,
})
