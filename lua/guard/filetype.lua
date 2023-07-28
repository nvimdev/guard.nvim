local M = {}

local function box()
  local current
  local tbl = {}
  tbl.__index = tbl

  function tbl:fmt(config)
    vim.validate({
      config = { config, { 't', 's' } },
    })
    self.format = {
      vim.deepcopy(config),
    }
    current = 'format'
    return self
  end

  function tbl:append(val)
    self[current][#self[current] + 1] = val
    return self
  end

  function tbl:lint(config)
    vim.validate({
      config = { config, { 't', 's' } },
    })
    current = 'linter'
    self.linter = {
      vim.deepcopy(config),
    }
    return self
  end

  function tbl:extra(...)
    local tool = self[current][#self[current]]
    if type(tool) == 'string' then
      tool = current == 'format' and require('guard.tools.formatter')[tool]
        or require('guard.tools.linter.' .. tool)
    end
    tool.args = vim.list_extend({ ... }, tool.args)
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
    for _, item in ipairs(cfg) do
      target[#target + 1] = vim.deepcopy(item)
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
