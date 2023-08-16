local diag_fmt = require('guard.lint').diag_fmt
return {
  cmd = 'luacheck',
  args = { '--formatter', 'plain', '--codes', '-', '--filename' },
  fname = true,
  stdin = true,
  output_fmt = function(result, buf)
    local lines = vim.split(result, '\n', { trimempty = true })

    if #lines < 1 then
      return {}
    end

    -- For each line, substring between parentheses contains
    -- three digit issue code, prefixed with E for errors and W for warnings.
    -- https://luacheck.readthedocs.io/en/stable/cli.html
    local severities = {
      E = 1,
      W = 2,
    }

    local diags = {}

    vim.tbl_map(function(line)
      local lnum, col, severity, code, message = line:match('(%d+):(%d+):%s%((%a)(%w+)%) (.+)')

      diags[#diags + 1] = diag_fmt(
        buf,
        tonumber(lnum) - 1,
        tonumber(col) - 1,
        message .. ' [' .. code .. ']',
        severities[severity] or 4,
        'luacheck'
      )
    end, lines)

    return diags
  end,
}
