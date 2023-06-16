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
    current = 'lint'
    self.lint = {
      vim.deepcopy(config),
    }
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
