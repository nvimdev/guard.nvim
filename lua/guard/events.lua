local api = vim.api
local group = api.nvim_create_augroup('Guard', { clear = true })
local ft_handler = require('guard.filetype')
local format = require('guard.format')

local function watch_ft(fts)
  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = fts,
    callback = function(args)
      format.attach_to_buf(args.buf)
    end,
    desc = 'guard',
  })
end

local function create_lspattach_autocmd(fmt_on_save)
  api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      ---@diagnostic disable-next-line: need-check-nil
      if not client.supports_method('textDocument/formatting') then
        return
      end
      local ft = vim.bo[args.buf].filetype
      if not (ft_handler[ft] and ft_handler[ft].format) then
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
        format.attach_to_buf(args.buf)
      end
    end,
  })
end

return {
  watch_ft = watch_ft,
  create_lspattach_autocmd = create_lspattach_autocmd,
}
