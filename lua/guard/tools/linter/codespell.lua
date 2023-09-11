local lint = require('guard.lint')
return {
  cmd = 'codespell',
  args = {
    '-',
  },
  stdin = true,
  parse = function(result, bufnr)
    local diags = {}
    local t = vim.split(result, '\n')
    for i, e in ipairs(t) do
      local lnum = e:match('^%d+')
      if lnum then
        diags[#diags + 1] =
          lint.diag_fmt(bufnr, tonumber(lnum) - 1, 0, t[i + 1]:gsub('\t', ''), 2, 'codespell')
      end
    end
    return diags
  end,
}
