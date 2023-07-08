local api = vim.api
local util = {}

function util.get_prev_lines(bufnr, srow, erow)
  local tbl = api.nvim_buf_get_lines(bufnr, srow, erow, false)
  local res = {}
  for _, text in ipairs(tbl) do
    res[#res + 1] = text .. '\n'
  end
  return res
end

function util.get_lsp_root()
  local curbuf = api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients({ bufnr = curbuf })
  if #clients == 0 then
    return
  end
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end
end

return util
