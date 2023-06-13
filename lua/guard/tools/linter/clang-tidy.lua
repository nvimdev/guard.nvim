return {
  cmd = 'clang-tidy',
  args = { '--quiet' },
  stdin = false,
  output_fmt = function(result, buf, ns)
    local map = {
      'error',
      'warning',
      'information',
      'hint',
      'note',
    }

    local text = vim.split(result, '\n')[1]
    local message
    local severity
    for idx, t in ipairs(map) do
      local _, p = text:find(t)
      if p then
        message = text:sub(p + 2, #text)
        severity = idx
        break
      end
    end
    local pos = text:match([[(%d+:%d+)]])
    local lnum, col = unpack(vim.split(pos, ':'))
    ---@diagnostic disable-next-line: cast-local-type
    lnum = tonumber(lnum)
    col = tonumber(col)

    return {
      bufnr = buf,
      col = col,
      end_col = col,
      end_lnum = lnum,
      lnum = lnum,
      message = message,
      namespace = ns,
      severity = severity,
      source = 'clang-tidy',
    }
  end,
}
