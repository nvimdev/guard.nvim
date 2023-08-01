---@diagnostic disable-next-line: deprecated
local get_clients = vim.version().minor >= 10 and vim.lsp.get_clients or vim.lsp.get_active_clients
local api = vim.api
local group = api.nvim_create_augroup('Guard', { clear = true })
local ft_handler = require('guard.filetype')
local attach_to_buf = require('guard.format').attach_to_buf
local util = {}

function util.get_prev_lines(bufnr, srow, erow)
  local tbl = api.nvim_buf_get_lines(bufnr, srow, erow, false)
  local res = {}
  for _, text in ipairs(tbl) do
    res[#res + 1] = text .. '\n'
  end
  return res
end

function util.get_lsp_root(buf)
  buf = buf or api.nvim_get_current_buf()
  local clients = get_clients({ bufnr = buf })
  if #clients == 0 then
    return
  end
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end
end

function util.as_table(t)
  return vim.tbl_islist(t) and t or { t }
end

function util.watch_ft(fts)
  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = fts,
    callback = function(args)
      attach_to_buf(args.buf)
    end,
    desc = 'guard',
  })
end

function util.create_lspattach_autocmd(fmt_on_save)
 api.nvim_create_autocmd('LspAttach', {
   callback = function(args)
     local client = vim.lsp.get_client_by_id(args.data.client_id)
     ---@diagnostic disable-next-line: need-check-nil
     if not client.supports_method('textDocument/formatting') then
       return
     end
     if ft_handler[vim.bo[args.buf].filetype] and ft_handler[vim.bo[args.buf].filetype].format then
       table.insert(ft_handler[vim.bo[args.buf].filetype].format, 1, 'lsp')
     else
       ft_handler(vim.bo[args.buf].filetype):fmt('lsp')
     end

     local ok, au = pcall(api.nvim_get_autocmds, {
           group = 'Guard',
           event = 'FileType',
           pattern = vim.bo[args.buf].filetype,
     })
     if
       fmt_on_save
       and ok
       and #au == 0
     then
       attach_to_buf(args.buf)
     end
   end,
 })
end

function util.disable(opts)
  if #opts.fargs == 0 then
    pcall(api.nvim_del_augroup_by_id, group)
    return
  end
  if not pcall(api.nvim_get_autocmds, { group = group }) then
    return
  end
  local arg = opts.args
  local _, bufnr = pcall(tonumber, arg)
  if bufnr then
    local bufau = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = bufnr })
    if #bufau ~= 0 then
      api.nvim_del_autocmd(bufau[1].id)
    end
  else
    local listener = api.nvim_get_autocmds({ group = group, event = 'FileType', pattern = arg })
    if #listener ~= 0 then
      api.nvim_del_autocmd(listener[1].id)
      local bufaus = api.nvim_get_autocmds({ group = group, event = 'BufWritePre' })
      for _, au in ipairs(bufaus) do
        if vim.bo[au].ft == arg then
          api.nvim_del_autocmd(au.id)
        end
      end
    end
 end
end

function util.enable(opts)
  if #opts.fargs == 0 and not pcall(api.nvim_get_autocmds, { group = group }) then
    util.watch_ft(ft_handler)
    return
  end
  local arg = opts.args
  local _, bufnr = pcall(tonumber, arg)
  if bufnr then
    local bufau = api.nvim_get_autocmds({ group = group, event = 'BufWritePre', buffer = bufnr })
    if #bufau == 0 then
      attach_to_buf(bufnr)
    end
  else
    local listener = api.nvim_get_autocmds({ group = group, event = 'FileType', pattern = arg })
    if #listener == 0 then
      util.watch_ft(arg)
    end
  end
end

return util
