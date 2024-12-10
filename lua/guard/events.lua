local api, uv = vim.api, vim.uv
local util = require('guard.util')
local getopt = util.getopt
local report_error = util.report_error
local au = api.nvim_create_autocmd
local iter = vim.iter
local M = {}
M.group = api.nvim_create_augroup('Guard', { clear = true })

local debounce_timer = nil
local debounced_lint = function(opt)
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

---@param bufnr number
---@return vim.api.keyset.get_autocmds.ret[]
function M.get_format_autocmds(bufnr)
  if not api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  return api.nvim_get_autocmds({ group = M.group, event = 'BufWritePre', buffer = bufnr })
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
      buffer = bufnr,
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
---@return boolean
function M.check_lint_should_attach(buf)
  return #M.get_lint_autocmds(buf) == 0 and vim.bo[buf].buftype ~= 'nofile'
end

---@param buf number
function M.try_attach_fmt_to_buf(buf)
  if not M.check_fmt_should_attach(buf) then
    return
  end
  au('BufWritePre', {
    group = M.group,
    buffer = buf,
    callback = function(opt)
      if vim.bo[opt.buf].modified and getopt('fmt_on_save') then
        require('guard.format').do_fmt(opt.buf)
      end
    end,
  })
end

---@param buf number
---@param events string[]
function M.try_attach_lint_to_buf(buf, events)
  if not M.check_lint_should_attach(buf) then
    return
  end

  for _, ev in ipairs(events) do
    if ev == 'User GuardFmt' then
      au('User', {
        group = M.group,
        pattern = 'GuardFmt',
        callback = function(opt)
          if opt.data.status == 'done' then
            debounced_lint(opt)
          end
        end,
      })
    else
      au(ev, {
        group = M.group,
        buffer = buf,
        callback = debounced_lint,
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
function M.fmt_watch_ft(ft)
  -- check if all cmds executable before registering formatter
  iter(require('guard.filetype')[ft].formatter):any(function(config)
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
      M.fmt_watch_ft(ft)
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
      if
        not client
        or not client.supports_method('textDocument/formatting', { bufnr = args.data.buf })
      then
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
      M.try_attach_lint_to_buf(args.buf, events)
    end,
  })
end

return M
