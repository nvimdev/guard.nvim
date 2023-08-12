local diag_fmt = require('guard.lint').diag_fmt
return {
  cmd = 'shellcheck',
  args = { '--format', 'json1', '--external-sources' },
  stdin = true,
  output_fmt = function(result, buf)
    local comments = vim.json.decode(result).comments

    if #comments < 1 then
      return {}
    end

    -- https://github.com/koalaman/shellcheck/blob/master/shellcheck.1.md
    -- "Valid values in order of severity are error, warning, info and style."
    local severities = {
      error = 1,
      warning = 2,
      info = 3,
      style = 4
    }

    local diags = {}

    vim.tbl_map(function(mes)
      diags[#diags + 1] = diag_fmt(
        buf,
        tonumber(mes.line) - 1,
        tonumber(mes.column) - 1,
        mes.message .. ' [' .. mes.code .. ']',
        severities[mes.level] or 4,
        'shellcheck'
      )
    end, comments)

    return diags
  end
}
