local lib = require('guard.lib')
local Result = lib.Result
local Async = lib.Async
local util = require('guard.util')
local api = vim.api
local uv = vim.uv

local M = {}

-- Autocmd group
M.group = api.nvim_create_augroup('Guard', { clear = true })

-- Track user-defined custom autocmds
M.custom_autocmds = {
  formatter = {},
  linter = {},
}

-- Debounce manager for lint operations
local DebounceManager = {}
DebounceManager.__index = DebounceManager

function DebounceManager.new()
  return setmetatable({
    timers = {}, -- bufnr -> timer
  }, DebounceManager)
end

function DebounceManager:debounce(bufnr, callback, delay)
  return Async.try(function()
    -- Cancel existing timer for this buffer
    self:cancel(bufnr)

    -- Create new timer
    local timer = uv.new_timer()
    if not timer then
      return Result.err('Failed to create timer')
    end

    self.timers[bufnr] = timer

    timer:start(delay, 0, function()
      timer:stop()
      timer:close()
      self.timers[bufnr] = nil

      vim.schedule(function()
        callback()
      end)
    end)

    return Result.ok(timer)
  end)
end

function DebounceManager:cancel(bufnr)
  local timer = self.timers[bufnr]
  if timer then
    timer:stop()
    timer:close()
    self.timers[bufnr] = nil
  end
end

function DebounceManager:cancel_all()
  for bufnr, _ in pairs(self.timers) do
    self:cancel(bufnr)
  end
end

-- Global debounce manager for lint
local lint_debouncer = DebounceManager.new()

-- Event handlers with Result
local Handlers = {}

-- Format handler
function Handlers.format(args)
  return Async.try(function()
    if not api.nvim_buf_is_valid(args.buf) then
      return Result.err('Invalid buffer')
    end

    if vim.bo[args.buf].modified and util.getopt('fmt_on_save') then
      require('guard.format').do_fmt(args.buf)
      return Result.ok('Formatted')
    end

    return Result.ok('Skipped')
  end)
end

-- Lint handler with debounce
function Handlers.lint(args)
  return Async.try(function()
    if not api.nvim_buf_is_valid(args.buf) then
      return Result.err('Invalid buffer')
    end

    if util.getopt('auto_lint') then
      local interval = util.getopt('lint_interval') or 500
      return lint_debouncer:debounce(args.buf, function()
        require('guard.lint').do_lint(args.buf)
      end, interval)
    end

    return Result.ok('Auto lint disabled')
  end)
end

-- Enhanced lint handler that triggers after format
function Handlers.lint_after_format(args)
  return Async.try(function()
    if args.buf and args.data and args.data.status == 'done' then
      return Handlers.lint({ buf = args.buf })
    end
    return Result.ok('Not triggered')
  end)
end

-- Autocmd management with Result
local AutocmdManager = {}

-- Validate buffer for autocmd attachment
function AutocmdManager.validate_buffer(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return Result.err('Invalid buffer')
  end

  if vim.bo[bufnr].buftype == 'nofile' then
    return Result.err('Buffer is nofile type')
  end

  return Result.ok(bufnr)
end

-- Get autocmds for a specific tool and buffer
function AutocmdManager.get_autocmds(tool_type, bufnr, events)
  return AutocmdManager.validate_buffer(bufnr)
    :map(function()
      local ft = vim.bo[bufnr].ft
      local custom_ids = M.custom_autocmds[tool_type][ft]

      -- If custom autocmds exist, return those
      if custom_ids and #custom_ids > 0 then
        return vim
          .iter(api.nvim_get_autocmds({ group = M.group }))
          :filter(function(au)
            return vim.tbl_contains(custom_ids, au.id)
          end)
          :totable()
      end

      -- Otherwise return standard autocmds
      events = events
        or (
          tool_type == 'formatter' and { 'BufWritePre' }
          or { 'BufWritePost', 'BufEnter', 'TextChanged', 'InsertLeave', 'User' }
        )

      local autocmds = {}
      for _, event in ipairs(events) do
        local opts = {
          group = M.group,
          event = event,
        }

        if event == 'User' then
          opts.pattern = 'GuardFmt'
        else
          opts.buffer = bufnr
        end

        vim.list_extend(autocmds, api.nvim_get_autocmds(opts))
      end

      return autocmds
    end)
    :unwrap_or({})
end

-- Check if autocmds should be attached
function AutocmdManager.should_attach(tool_type, bufnr, ft)
  return AutocmdManager.validate_buffer(bufnr):and_then(function()
    -- Check existing autocmds
    local existing = AutocmdManager.get_autocmds(tool_type, bufnr)

    if tool_type == 'formatter' then
      if #existing > 0 then
        return Result.err('Formatter already attached')
      end
    else
      -- For linters, check specific patterns
      local filtered = vim
        .iter(existing)
        :filter(ft == '*' and function(au)
          return au.pattern == '*'
        end or function(au)
          return au.pattern ~= '*'
        end)
        :totable()

      if #filtered > 0 then
        return Result.err('Linter already attached')
      end
    end

    return Result.ok(true)
  end)
end

-- Create autocmd with proper options
function AutocmdManager.create_autocmd(event, opts)
  return Async.try(function()
    opts = opts or {}
    opts.group = M.group

    if not opts.callback and not opts.command then
      return Result.err('Autocmd requires either callback or command')
    end

    local id = api.nvim_create_autocmd(event, opts)
    return Result.ok(id)
  end)
end

-- Attach formatters with Result
function M.try_attach_fmt_to_buf(bufnr)
  local should_attach = AutocmdManager.should_attach('formatter', bufnr)

  if should_attach:is_err() then
    return should_attach
  end

  return AutocmdManager.create_autocmd('BufWritePre', {
    buffer = bufnr,
    callback = function(args)
      local result = Handlers.format(args)
      if result:is_err() and vim.g.guard_debug then
        vim.notify('[Guard Debug] Format failed: ' .. result.error)
      end
    end,
    desc = 'Guard auto-format',
  })
end

-- Attach linters with Result
function M.try_attach_lint_to_buf(bufnr, events, ft)
  local should_attach = AutocmdManager.should_attach('linter', bufnr, ft)

  if should_attach:is_err() then
    return should_attach
  end

  local results = {}

  for _, event in ipairs(events) do
    local result
    if event == 'User GuardFmt' then
      result = AutocmdManager.create_autocmd('User', {
        pattern = 'GuardFmt',
        callback = function(args)
          local lint_result = Handlers.lint_after_format(args)
          if lint_result:is_err() and vim.g.guard_debug then
            vim.notify('[Guard Debug] Lint after format failed: ' .. lint_result.error)
          end
        end,
        desc = 'Guard lint after format',
      })
    else
      result = AutocmdManager.create_autocmd(event, {
        buffer = bufnr,
        callback = function(args)
          local lint_result = Handlers.lint(args)
          if lint_result:is_err() and vim.g.guard_debug then
            vim.notify('[Guard Debug] Lint failed: ' .. lint_result.error)
          end
        end,
        desc = 'Guard auto-lint',
      })
    end

    table.insert(results, result)
  end

  -- Check if all succeeded
  local failed = vim.iter(results):find(function(r)
    return r:is_err()
  end)
  if failed then
    return failed
  end

  return Result.ok(results)
end

-- Attach to existing buffers with Result handling
function M.fmt_attach_to_existing(ft)
  local results = {}

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(bufnr) and (ft == '*' or vim.bo[bufnr].ft == ft) then
      table.insert(results, M.try_attach_fmt_to_buf(bufnr))
    end
  end

  return Result.ok(results)
end

function M.lint_attach_to_existing(ft, events)
  local results = {}

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(bufnr) and (ft == '*' or vim.bo[bufnr].ft == ft) then
      table.insert(results, M.try_attach_lint_to_buf(bufnr, events, ft))
    end
  end

  return Result.ok(results)
end

-- Validate formatters and setup FileType autocmd
function M.fmt_on_filetype(ft, formatters)
  -- Validate formatters
  local validation_results = vim
    .iter(formatters)
    :map(function(config)
      if type(config) == 'table' and config.cmd then
        if vim.fn.executable(config.cmd) ~= 1 then
          return Result.err(config.cmd .. ' not executable')
        end
      end
      return Result.ok(config)
    end)
    :totable()

  -- Check if any validation failed
  local first_error = vim.iter(validation_results):find(function(r)
    return r:is_err()
  end)

  if first_error then
    util.report_error(first_error.error)
    return first_error
  end

  return AutocmdManager.create_autocmd('FileType', {
    pattern = ft,
    callback = function(args)
      local result = M.try_attach_fmt_to_buf(args.buf)
      if result:is_err() and vim.g.guard_debug then
        vim.notify('[Guard Debug] Failed to attach formatter: ' .. result.error)
      end
    end,
    desc = 'Guard formatter setup for ' .. ft,
  })
end

-- Validate linters and setup FileType autocmd
function M.lint_on_filetype(ft, events)
  -- Get linter config for validation
  local ft_config = require('guard.filetype')[ft]
  if not ft_config or not ft_config.linter then
    return Result.err('No linter configuration for ' .. ft)
  end

  -- Validate linters
  local validation_results = vim
    .iter(ft_config.linter)
    :map(function(config)
      if config.cmd and vim.fn.executable(config.cmd) ~= 1 then
        return Result.err(config.cmd .. ' not executable')
      end
      return Result.ok(config)
    end)
    :totable()

  -- Report all errors
  vim
    .iter(validation_results)
    :filter(function(r)
      return r:is_err()
    end)
    :each(function(r)
      util.report_error(r.error)
    end)

  return AutocmdManager.create_autocmd('FileType', {
    pattern = ft,
    callback = function(args)
      local result = M.try_attach_lint_to_buf(args.buf, events, ft)
      if result:is_err() and vim.g.guard_debug then
        vim.notify('[Guard Debug] Failed to attach linter: ' .. result.error)
      end
    end,
    desc = 'Guard linter setup for ' .. ft,
  })
end

-- Custom event handling with Result
function M.fmt_attach_custom(ft, events)
  return Async.try(function()
    M.custom_autocmds.formatter[ft] = M.custom_autocmds.formatter[ft] or {}

    local results = {}
    for _, event in ipairs(events) do
      local opts = vim.deepcopy(event.opt or {})

      -- Ensure callback
      if not opts.callback and not opts.command then
        opts.callback = function(args)
          require('guard.format').do_fmt(args.buf)
        end
      end

      -- Set group and description
      opts.group = M.group
      opts.desc = opts.desc or ('Guard custom format for %s'):format(ft)

      local result = AutocmdManager.create_autocmd(event.name, opts)

      result:match({
        ok = function(id)
          table.insert(M.custom_autocmds.formatter[ft], id)
        end,
        err = function(err)
          table.insert(results, Result.err(err))
        end,
      })
    end

    -- Return first error if any
    local first_error = vim.iter(results):find(function(r)
      return r:is_err()
    end)
    return first_error or Result.ok(M.custom_autocmds.formatter[ft])
  end)
end

function M.lint_attach_custom(ft, config)
  return Async.try(function()
    M.custom_autocmds.linter[ft] = M.custom_autocmds.linter[ft] or {}

    local results = {}
    for _, event in ipairs(config.events) do
      local opts = vim.deepcopy(event.opt or {})

      -- Ensure callback
      if not opts.callback and not opts.command then
        opts.callback = function(args)
          Async.async(function()
            require('guard.lint').do_lint_single(args.buf, config)
          end)()
        end
      end

      -- Set group and description
      opts.group = M.group
      opts.desc = opts.desc or ('Guard custom lint for %s'):format(ft)

      local result = AutocmdManager.create_autocmd(event.name, opts)

      result:match({
        ok = function(id)
          table.insert(M.custom_autocmds.linter[ft], id)
        end,
        err = function(err)
          table.insert(results, Result.err(err))
        end,
      })
    end

    -- Return first error if any
    local first_error = vim.iter(results):find(function(r)
      return r:is_err()
    end)
    return first_error or Result.ok(M.custom_autocmds.linter[ft])
  end)
end

-- LSP integration with Result
function M.maybe_default_to_lsp(config, ft, bufnr)
  if config.formatter then
    return Result.ok('Formatter already configured')
  end

  return Async.try(function()
    config:fmt('lsp')

    if util.getopt('fmt_on_save') then
      -- Check if FileType autocmd already exists
      local existing = api.nvim_get_autocmds({
        group = M.group,
        event = 'FileType',
        pattern = ft,
      })

      if #existing == 0 then
        local result = M.fmt_on_filetype(ft, config.formatter)
        if result:is_err() then
          return result
        end
      end

      return M.try_attach_fmt_to_buf(bufnr)
    end

    return Result.ok('LSP formatter configured')
  end)
end

function M.create_lspattach_autocmd()
  return AutocmdManager.create_autocmd('LspAttach', {
    callback = function(args)
      if not util.getopt('lsp_as_default_formatter') then
        return
      end

      local result = Async.try(function()
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
          return Result.err('LSP client not found')
        end

        if not client:supports_method('textDocument/formatting', args.buf) then
          return Result.err("LSP client doesn't support formatting")
        end

        local ft_handler = require('guard.filetype')
        local ft = vim.bo[args.buf].filetype
        return M.maybe_default_to_lsp(ft_handler(ft), ft, args.buf)
      end)

      if result:is_err() and vim.g.guard_debug then
        vim.notify('[Guard Debug] LSP setup failed: ' .. result.error)
      end
    end,
    desc = 'Guard LSP formatter setup',
  })
end

-- Public API for getting autocmds
function M.get_format_autocmds(bufnr)
  return AutocmdManager.get_autocmds('formatter', bufnr, { 'BufWritePre' })
end

function M.get_lint_autocmds(bufnr)
  return AutocmdManager.get_autocmds('linter', bufnr)
end

-- Cleanup on plugin unload
function M.cleanup()
  return Async.try(function()
    -- Cancel all pending lint operations
    lint_debouncer:cancel_all()

    -- Clear all autocmds in the group
    api.nvim_clear_autocmds({ group = M.group })

    -- Clear custom autocmd tracking
    M.custom_autocmds = {
      formatter = {},
      linter = {},
    }

    return Result.ok('Cleanup completed')
  end)
end

return M
