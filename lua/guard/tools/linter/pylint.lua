local diag_fmt = require('guard.lint').diag_fmt
return {
  cmd = 'pylint',
  args = { '--from-stdin' },
  stdin = true,
  output_fmt = function(result, buf)
    local output = vim.split(result, '\n')
    local patterns = {
      'E%d+',
      'W%d+',
      'C%d+',
    }
    local diags = {}
    for _, line in ipairs(output) do
      for i, pattern in ipairs(patterns) do
        if line:find(pattern) then
          local pos = line:match('py:(%d+:%d+)')
          local lnum, col = unpack(vim.split(pos, ':'))
          local mes = line:match('%d:%s(.*)')
          diags[#diags + 1] = diag_fmt(buf, tonumber(lnum), tonumber(col), mes, i, 'pylint')
        end
      end
    end

    return diags
  end,
}
