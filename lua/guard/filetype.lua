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

  function tbl:register(key, config)
    vim.validate({
      key = {
        key,
        function(val)
          return val == 'lint'
            or val == 'linter'
            or val == 'fmt'
            or val == 'format'
            or val == 'formatter'
        end,
      },
      config = { config, { 't', 's' } },
    })
    current = key
    if key == 'lint' or key == 'linter' then
      self.linter = {
        vim.deepcopy(config),
      }
    else
      self.current = 'format'
      self.format = {
        vim.deepcopy(config),
      }
    end

    return self
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
