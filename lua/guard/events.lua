local api, uv = vim.api, vim.uv
local util = require('guard.util')
local getopt = util.getopt
local report_error = util.report_error
local au = api.nvim_create_autocmd
local iter = vim.iter
local M = {}
M.group = api.nvim_create_augroup('Guard', { clear = true })

function M.try_attach_to_buf(buf)
  if
    #api.nvim_get_autocmds({
      group = M.group,
      event = 'BufWritePre',
      buffer = buf,
    }) > 0
  then
    -- already attached
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

---@param ft string
function M.fmt_attach_to_existing(ft)
  local bufs = api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    if vim.bo[buf].ft == ft then
      M.try_attach_to_buf(buf)
    end
  end
end

---@param ft string
function M.watch_ft(ft)
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
      M.try_attach_to_buf(args.buf)
    end,
    desc = 'guard',
  })
end

---@param config table
---@param ft string
---@param buf number
function M.maybe_default_to_lsp(config, ft, buf)
  if config and config.formatter then
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
      M.watch_ft(ft)
    end
    M.try_attach_to_buf(buf)
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
      if client and not client.supports_method('textDocument/formatting') then
        return
      end
      local ft_handler = require('guard.filetype')
      local ft = vim.bo[args.buf].filetype
      M.maybe_default_to_lsp(ft_handler[ft], ft, args.buf)
    end,
  })
end

local debounce_timer = nil
function M.register_lint(ft, events)
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
      local cb = function(opt)
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
      for _, ev in ipairs(events) do
        if ev == 'User GuardFmt' then
          au('User', {
            group = M.group,
            pattern = 'GuardFmt',
            callback = function(opt)
              if opt.data.status == 'done' then
                cb(opt)
              end
            end,
          })
        else
          au(ev, {
            group = M.group,
            buffer = args.buf,
            callback = cb,
          })
        end
      end
    end,
  })
end

return M
