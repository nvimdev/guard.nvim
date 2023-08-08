local api = vim.api
local format = require('guard.format')

local function disable(opts)
  local arg = opts.args
  local bufnr = (#opts.fargs == 0) and api.nvim_get_current_buf() or tonumber(arg)
  if bufnr then
    local bufau = api.nvim_get_autocmds({ group = 'Guard', event = 'BufWritePre', buffer = bufnr })
    if #bufau ~= 0 then
      api.nvim_del_autocmd(bufau[1].id)
    end
  end
end

local function enable(opts)
  local arg = opts.args
  local bufnr = (#opts.fargs == 0) and api.nvim_get_current_buf() or tonumber(arg)
  if bufnr then
    local bufau = api.nvim_get_autocmds({ group = 'Guard', event = 'BufWritePre', buffer = bufnr })
    if #bufau == 0 then
      format.attach_to_buf(bufnr)
    end
  end
end

return {
  disable = disable,
  enable = enable,
}
