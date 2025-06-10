local lib = require('guard.lib')
local Result = lib.Result
local util = require('guard.util')

local M = {}

-- Tool loader with Result error handling
local ToolLoader = {}

function ToolLoader.get(tool_type, tool_name)
  if tool_name == 'lsp' then
    return Result.ok({ fn = require('guard.lsp').format })
  end

  local ok, collection = pcall(require, 'guard-collection.' .. tool_type)
  if not ok then
    return Result.err(
      string.format(
        '"%s" needs nvimdev/guard-collection to access builtin configuration',
        tool_name
      )
    )
  end

  if not collection[tool_name] then
    return Result.err(string.format('%s "%s" has no builtin configuration', tool_type, tool_name))
  end

  return Result.ok(collection[tool_name])
end

function ToolLoader.resolve(tool_type, config)
  if type(config) == 'function' then
    return Result.ok(config)
  elseif type(config) == 'table' then
    return Result.ok(config)
  elseif type(config) == 'string' then
    return ToolLoader.get(tool_type, config)
  else
    return Result.err(
      string.format(
        'Invalid %s config type: %s (expected string/table/function)',
        tool_type,
        type(config)
      )
    )
  end
end

-- Filetype configuration builder
local FiletypeConfig = {}
FiletypeConfig.__index = FiletypeConfig

function FiletypeConfig.new(filetypes)
  local ft_string = type(filetypes) == 'table' and table.concat(filetypes, ',') or filetypes
  local ft_list = vim.split(ft_string, ',', { trimempty = true })

  return setmetatable({
    _filetypes = ft_list,
    _original_ft = ft_string,
    _current_tool = nil,
    formatter = {},
    linter = {},
  }, FiletypeConfig)
end

-- Get list of filetypes
function FiletypeConfig:filetypes()
  return self._filetypes
end

-- Generic tool setup
function FiletypeConfig:_setup_tool(tool_type, config)
  local result = ToolLoader.resolve(tool_type, config)

  if result:is_err() then
    vim.notify('[Guard]: ' .. result.error, vim.log.levels.WARN)
    return self
  end

  -- Set current tool type and initialize
  self._current_tool = tool_type
  self[tool_type] = { util.toolcopy(result.value) }

  -- Setup events
  self:_attach_events(tool_type, config)

  -- Copy to other filetypes if needed
  if #self._filetypes > 1 then
    self:_propagate_to_filetypes(tool_type)
  end

  return self
end

-- Attach events for tools
function FiletypeConfig:_attach_events(tool_type, config)
  local events = require('guard.events')

  for _, ft in ipairs(self._filetypes) do
    if type(config) == 'table' and config.events then
      -- Custom events
      if tool_type == 'formatter' then
        events.fmt_attach_custom(ft, config.events)
      else
        events.lint_attach_custom(ft, config)
      end
    else
      -- Default events
      if tool_type == 'formatter' then
        events.fmt_on_filetype(ft, self.formatter)
        events.fmt_attach_to_existing(ft)
      else
        local evs = util.linter_events(config)
        events.lint_on_filetype(ft, evs)
        events.lint_attach_to_existing(ft, evs)
      end
    end
  end
end

-- Propagate configuration to related filetypes
function FiletypeConfig:_propagate_to_filetypes(tool_type)
  for _, ft in ipairs(self._filetypes) do
    if ft ~= self._original_ft then
      if not M[ft] then
        M[ft] = FiletypeConfig.new(ft)
      end
      M[ft][tool_type] = self[tool_type]
    end
  end

  -- Clean up composite filetype entry
  if self._original_ft:find(',') then
    M[self._original_ft] = nil
  end
end

-- Public API methods
function FiletypeConfig:fmt(config)
  return self:_setup_tool('formatter', config)
end

function FiletypeConfig:lint(config)
  return self:_setup_tool('linter', config)
end

function FiletypeConfig:append(config)
  if not self._current_tool then
    vim.notify('[Guard]: No tool selected to append to', vim.log.levels.WARN)
    return self
  end

  local result = ToolLoader.resolve(self._current_tool, config)
  if result:is_err() then
    vim.notify('[Guard]: ' .. result.error, vim.log.levels.WARN)
    return self
  end

  local tool = util.toolcopy(result.value)
  table.insert(self[self._current_tool], tool)

  -- Handle custom events for linters
  if self._current_tool == 'linter' and type(config) == 'table' and config.events then
    for _, ft in ipairs(self._filetypes) do
      require('guard.events').lint_attach_custom(ft, config)
    end
  end

  return self
end

function FiletypeConfig:extra(...)
  if not self._current_tool then
    return self
  end

  local tools = self[self._current_tool]
  if #tools == 0 then
    return self
  end

  local tool = tools[#tools]
  tool.args = vim.list_extend(tool.args or {}, { ... })
  return self
end

function FiletypeConfig:env(env_table)
  if type(env_table) ~= 'table' or vim.tbl_count(env_table) == 0 then
    return self
  end

  if not self._current_tool then
    return self
  end

  local tools = self[self._current_tool]
  if #tools == 0 then
    return self
  end

  local tool = tools[#tools]
  tool.env = env_table
  return self
end

-- Check if buffer is valid for formatting/linting
function FiletypeConfig:valid_buf(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  -- Check both formatters and linters
  local check_tools = function(tools)
    if not tools or #tools == 0 then
      return true
    end

    return vim.iter(tools):all(function(tool)
      if type(tool) ~= 'table' or not tool.ignore_patterns then
        return true
      end

      local patterns = util.as_table(tool.ignore_patterns)
      return not vim.iter(patterns):any(function(pattern)
        return bufname:find(pattern) ~= nil
      end)
    end)
  end

  return check_tools(self.formatter) and check_tools(self.linter)
end

-- Check if configuration has any tools
function FiletypeConfig:has_tools()
  return (#self.formatter > 0) or (#self.linter > 0)
end

-- Get all configured tools
function FiletypeConfig:get_tools(tool_type)
  if tool_type then
    return self[tool_type] or {}
  end

  return {
    formatter = self.formatter,
    linter = self.linter,
  }
end

-- Module metatable for convenient access
return setmetatable(M, {
  __call = function(_, filetypes)
    local key = type(filetypes) == 'table' and table.concat(filetypes, ',') or filetypes

    if not M[key] then
      M[key] = FiletypeConfig.new(filetypes)
    end

    return M[key]
  end,
})
