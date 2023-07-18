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

  return setmetatable({}, tbl)
end


local function box_for_group(fts)
  for _, ft in pairs(fts) do
    if not rawget(M, ft) then
      rawset(M, ft, box())
    end
  end
  local current
  local tbl = {}
  tbl.__index = tbl

  function tbl:fmt(config)
    for _, ft in pairs(self) do
      M[ft]:fmt(config)
    end
    current = 'format'
    return self
  end

  function tbl:append(val)
    for _, ft in pairs(self) do
      local opt = M[ft][current]
      opt[#opt + 1] = val
    end
    return self
  end

  function tbl:lint(config)
    for _, ft in pairs(self) do
      M[ft]:lint(config)
    end
    current = 'linter'
    return self
  end

  return setmetatable(fts, tbl)
end

return setmetatable(M, {
  __call = function(t, ft)
    if type(ft) == "table" then
      return box_for_group(ft)
    end
    if not rawget(t, ft) then
      rawset(t, ft, box())
    end
    return t[ft]
  end,
})
