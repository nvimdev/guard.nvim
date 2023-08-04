local api = vim.api
local ft_handler = require('guard.filetype')
local events = require('guard.events')
local format = require('guard.format')

local function disable(opts)
  local guard_aus = api.nvim_get_autocmds({ group = 'Guard' })
  if #opts.fargs == 0 then
    for _, au in ipairs(guard_aus) do
      api.nvim_del_autocmd(au.id)
    end
    return
  end
  if #guard_aus == 0 then
    return
  end
  local arg = opts.args
  local bufnr = tonumber(arg)
  if bufnr then
    local bufau = api.nvim_get_autocmds({ group = 'Guard', event = 'BufWritePre', buffer = bufnr })
    if #bufau ~= 0 then
      api.nvim_del_autocmd(bufau[1].id)
    end
  else
    local listener = api.nvim_get_autocmds({ group = 'Guard', event = 'FileType', pattern = arg })
    if #listener ~= 0 then
      api.nvim_del_autocmd(listener[1].id)
    end
    local bufaus = api.nvim_get_autocmds({ group = 'Guard', event = 'BufWritePre' })
    for _, au in ipairs(bufaus) do
      if vim.bo[au.buffer].ft == arg then
        api.nvim_del_autocmd(au.id)
      end
    end
 end
end

local function enable(opts)
  if #opts.fargs == 0 and #api.nvim_get_autocmds({ group = 'Guard' }) == 0 then
    local pattern = vim.tbl_keys(ft_handler)
    events.watch_ft(pattern)
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if vim.tbl_contains(pattern, vim.bo[buf].ft) then
        format.attach_to_buf(buf)
      end
    end
    return
  end
  local arg = opts.args
  local bufnr = tonumber(arg)
  if bufnr then
    local bufau = api.nvim_get_autocmds({ group = 'Guard', event = 'BufWritePre', buffer = bufnr })
    if #bufau == 0 then
      format.attach_to_buf(bufnr)
    end
  else
    local listener = api.nvim_get_autocmds({ group = 'Guard', event = 'FileType', pattern = arg })
    if #listener == 0 then
      events.watch_ft(arg)
    end
    for _, buf in ipairs(api.nvim_list_bufs()) do
      if vim.bo[buf].ft == arg then
        format.attach_to_buf(buf)
      end
    end
  end
end

return {
  disable = disable,
  enable = enable,
}
