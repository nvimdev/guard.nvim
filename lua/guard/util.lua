local api = vim.api
local util = {}

function util.get_prev_lines(bufnr)
  local tbl = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local res = {}
  for _, text in ipairs(tbl) do
    res[#res + 1] = text .. '\n'
  end
  return res
end

return util
