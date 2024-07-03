local api, uv = vim.api, vim.uv
local group = api.nvim_create_augroup('Guard', { clear = true })
local au = api.nvim_create_autocmd
local iter = vim.iter
local M = {}

function M.attach_to_buf(buf)
  au('BufWritePre', {
    group = group,
    buffer = buf,
    callback = function(opt)
      if vim.bo[opt.buf].modified then
        require('guard.format').do_fmt(opt.buf)
      end
    end,
  })
end

function M.watch_ft(ft)
  -- check if all cmds executable before registering formatter
  iter(require('guard.filetype')[ft].formatter):any(function(config)
    if config.cmd and vim.fn.executable(config.cmd) ~= 1 then
      error(config.cmd .. ' not executable', 1)
    end
    return true
  end)

  au('FileType', {
    group = group,
    pattern = ft,
    callback = function(args)
      if
        #api.nvim_get_autocmds({
          group = group,
          event = 'BufWritePre',
          buffer = args.buf,
        }) == 0
      then
        M.attach_to_buf(args.buf)
      end
    end,
    desc = 'guard',
  })
end

function M.create_lspattach_autocmd(fmt_on_save)
  au('LspAttach', {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      ---@diagnostic disable-next-line: need-check-nil
      if not client.supports_method('textDocument/formatting') then
        return
      end
      local ft_handler = require('guard.filetype')
      local ft = vim.bo[args.buf].filetype
      if not (ft_handler[ft] and ft_handler[ft].formatter) then
        ft_handler(ft):fmt('lsp')
      end
      if
        fmt_on_save
        and #api.nvim_get_autocmds({
            group = group,
            event = 'FileType',
            pattern = ft,
          })
          == 0
      then
        M.attach_to_buf(args.buf)
      end
    end,
  })
end

local debounce_timer = nil
function M.register_lint(ft, events)
  iter(require('guard.filetype')[ft].linter):any(function(config)
    if config.cmd and vim.fn.executable(config.cmd) ~= 1 then
      error(config.cmd .. ' not executable', 1)
    end
    return true
  end)

  au('FileType', {
    pattern = ft,
    group = group,
    callback = function(args)
      local cb = function(opt)
        if debounce_timer then
          debounce_timer:stop()
          debounce_timer = nil
        end
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
            group = group,
            pattern = 'GuardFmt',
            callback = function(opt)
              if opt.data.status == 'done' then
                cb(opt)
              end
            end,
          })
        else
          au(ev, {
            group = group,
            buffer = args.buf,
            callback = cb,
          })
        end
      end
    end,
  })
end

return M
