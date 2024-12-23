local api, uv = vim.api, vim.uv
local util = require('guard.util')
local getopt = util.getopt
local report_error = util.report_error
local au = api.nvim_create_autocmd
local iter = vim.iter
local M = {}
M.group = api.nvim_create_augroup('Guard', { clear = true })

M.user_fmt_autocmds = {}
M.user_lint_autocmds = {}

local debounce_timer = nil
local function debounced_lint(opt)
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer = nil
  end
  ---@diagnostic disable-next-line: undefined-field
  debounce_timer = assert(uv.new_timer()) --[[uv_timer_t]]
  debounce_timer:start(500, 0, function()
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
    vim.schedule(function()
      require('guard.lint').do_lint(opt.buf)
    end)
  end)
end

local function lazy_debounced_lint(opt)
  if getopt('auto_lint') == true then
    debounced_lint(opt)
  end
end

local function lazy_fmt(opt)
  if vim.bo[opt.buf].modified and getopt('fmt_on_save') then
    require('guard.format').do_fmt(opt.buf)
  end
end

---@param opt AuOption
---@param cb function
---@return AuOption
local function maybe_fill_auoption(opt, cb)
  local result = vim.deepcopy(opt, false)
  result.callback = (not result.command and not result.callback) and cb or result.callback
  result.group = M.group
  return result
end

---@param bufnr number
---@return number[]
function M.get_format_autocmds(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  return M.user_fmt_autocmds[vim.bo[bufnr].ft]
    or iter(api.nvim_get_autocmds({ group = M.group, event = 'BufWritePre', buffer = bufnr })):map(
      function(it)
        return it.id
      end
    )
end

---@param bufnr number
---@return vim.api.keyset.get_autocmds.ret[]
function M.get_lint_autocmds(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local aus = api.nvim_get_autocmds({
    group = M.group,
    event = { 'BufWritePost', 'BufEnter', 'TextChanged', 'InsertLeave' },
    buffer = bufnr,
  })
  return vim.list_extend(
    aus,
    api.nvim_get_autocmds({
      group = M.group,
      event = 'User',
      pattern = 'GuardFmt',
    })
  )
end

---@param buf number
---@return boolean
function M.check_fmt_should_attach(buf)
  -- check if it's not attached already and has an underlying file
  return #M.get_format_autocmds(buf) == 0 and vim.bo[buf].buftype ~= 'nofile'
end

---@param buf number
---@param ft string
---@return boolean
function M.check_lint_should_attach(buf, ft)
  if vim.bo[buf].buftype == 'nofile' then
    return false
  end

  local aus = M.get_lint_autocmds(buf)

  return #iter(aus)
    :filter(ft == '*' and function(it)
      return it.pattern == '*'
    end or function(it)
      return it.pattern ~= '*'
    end)
    :totable() == 0
end

---@param buf number
function M.try_attach_fmt_to_buf(buf)
  if not M.check_fmt_should_attach(buf) then
    return
  end
  au('BufWritePre', {
    group = M.group,
    buffer = buf,
    callback = lazy_fmt,
  })
end

---@param buf number
---@param events string[]
---@param ft string
function M.try_attach_lint_to_buf(buf, events, ft)
  if not M.check_lint_should_attach(buf, ft) then
    return
  end

  for _, ev in ipairs(events) do
    if ev == 'User GuardFmt' then
      au('User', {
        group = M.group,
        pattern = 'GuardFmt',
        callback = function(opt)
          if opt.data.status == 'done' then
            lazy_debounced_lint(opt)
          end
        end,
      })
    else
      au(ev, {
        group = M.group,
        buffer = buf,
        callback = lazy_debounced_lint,
      })
    end
  end
end

---@param ft string
function M.fmt_attach_to_existing(ft)
  local bufs = api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if vim.bo[buf].ft == ft then
      M.try_attach_fmt_to_buf(buf)
    end
  end
end

---@param ft string
---@param formatters FmtConfig[]
function M.fmt_watch_ft(ft, formatters)
  -- check if all cmds executable before registering formatter
  iter(formatters):any(function(config)
    if type(config) == 'table' and config.cmd and vim.fn.executable(config.cmd) ~= 1 then
      report_error(config.cmd .. ' not executable')
      return false
    end
    return true
  end)

  au('FileType', {
    group = M.group,
    pattern = ft,
    callback = function(args)
      M.try_attach_fmt_to_buf(args.buf)
    end,
    desc = 'guard',
  })
end

---@param config table
---@param ft string
---@param buf number
function M.maybe_default_to_lsp(config, ft, buf)
  if config.formatter then
    return
  end
  config:fmt('lsp')
  if getopt('fmt_on_save') then
    if
      #api.nvim_get_autocmds({
        group = M.group,
        event = 'FileType',
        pattern = ft,
      }) == 0
    then
      M.fmt_watch_ft(ft, config.formatter)
    end
    M.try_attach_fmt_to_buf(buf)
  end
end

function M.create_lspattach_autocmd()
  au('LspAttach', {
    group = M.group,
    callback = function(args)
      if not getopt('lsp_as_default_formatter') then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client or not client:supports_method('textDocument/formatting', args.data.buf) then
        return
      end
      local ft_handler = require('guard.filetype')
      local ft = vim.bo[args.buf].filetype
      M.maybe_default_to_lsp(ft_handler(ft), ft, args.buf)
    end,
  })
end

function M.lint_watch_ft(ft, events)
  iter(require('guard.filetype')[ft].linter):any(function(config)
    if config.cmd and vim.fn.executable(config.cmd) ~= 1 then
      report_error(config.cmd .. ' not executable')
    end
    return true
  end)

  au('FileType', {
    pattern = ft,
    group = M.group,
    callback = function(args)
      M.try_attach_lint_to_buf(args.buf, events, ft)
    end,
  })
end

---@param events EventOption[]
---@param ft string
function M.fmt_attach_custom(ft, events)
  M.user_fmt_autocmds[ft] = {}
  -- we don't know what autocmds are passed in, so these are attached asap
  iter(events):each(function(event)
    table.insert(
      M.user_fmt_autocmds[ft],
      api.nvim_create_autocmd(
        event.name,
        maybe_fill_auoption(event.opt or {}, function(opt)
          require('guard.format').do_fmt(opt.buf)
        end)
      )
    )
  end)
end

---@param config LintConfig
---@param ft string
function M.lint_attach_custom(ft, config)
  M.user_lint_autocmds[ft] = {}
  -- we don't know what autocmds are passed in, so these are attached asap
  iter(config.events):each(function(event)
    table.insert(
      M.user_lint_autocmds[ft],
      api.nvim_create_autocmd(
        event.name,
        maybe_fill_auoption(event.opt or {}, function(opt)
          coroutine.resume(coroutine.create(function()
            require('guard.lint').do_lint_single(opt.buf, config)
          end))
        end)
      )
    )
  end)
end

return M
