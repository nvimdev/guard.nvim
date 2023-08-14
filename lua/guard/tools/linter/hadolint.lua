local diag_fmt = require('guard.lint').diag_fmt
return {
  cmd = 'hadolint',
  args = { '--no-fail', '--format=json' },
  stdin = true,
  output_fmt = function(result, buf)
    local offenses = vim.json.decode(result)

    if not offenses or #offenses < 1 then
      return {}
    end

    local severities = {
      error = 1,
      warning = 2,
      info = 3,
      style = 4,
    }

    local diags = {}

    vim.tbl_map(function(mes)
      diags[#diags + 1] = diag_fmt(
        buf,
        tonumber(mes.line) - 1,
        tonumber(mes.column) - 1,
        mes.message .. ' [' .. mes.code .. ']',
        severities[mes.level] or 4,
        'hadolint'
      )
    end, offenses)

    return diags
  end,
}
