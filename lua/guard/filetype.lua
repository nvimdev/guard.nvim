local M = {}

local function insert()
  local t = {}
  t.__index = t
  function t:append(val)
    self[#self + 1] = val
    return self
  end
  return t
end

local function box()
  local tbl = {}
  tbl.__index = tbl

  function tbl:fmt(config)
    vim.validate({
      config = { config, { 't', 's' } },
    })
    self.format = setmetatable({
      vim.deepcopy(config),
    }, insert())
    return self.format
  end

  function tbl:lint(config)
    vim.validate({
      config = { config, { 't', 's' } },
    })
    self.linter = setmetatable({
      vim.deepcopy(config),
    }, insert())
    return self.linter
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
