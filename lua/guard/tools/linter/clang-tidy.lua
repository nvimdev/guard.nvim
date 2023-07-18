local diag_fmt = require('guard.lint').diag_fmt

return {
  cmd = 'clang-tidy',
  args = { '--quiet' },
  stdin = false,
  output_fmt = function(result, buf)
    local map = {
      'error',
      'warning',
      'information',
      'hint',
      'note',
    }

    local messages = vim.split(result, '\n')
    local diags = {}
    vim.tbl_map(function(mes)
      local message
      local severity
      for idx, t in ipairs(map) do
        local _, p = mes:find(t)
        if p then
          message = mes:sub(p + 2, #mes)
          severity = idx
          local pos = mes:match([[(%d+:%d+)]])
          local lnum, col = unpack(vim.split(pos, ':'))
          diags[#diags + 1] = diag_fmt(
            buf,
            tonumber(lnum) - 1,
            tonumber(col),
            message,
            severity > 4 and 4 or severity,
            'clang-tidy'
          )
        end
      end
    end, messages)

    return diags
  end,
}
