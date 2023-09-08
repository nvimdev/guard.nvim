local lint = require('guard.lint')

return {
  cmd = 'selene',
  args = { '--no-summary', '--display-style', 'json2' },
  stdin = true,
  parse = lint.from_json({
    attributes = {
      lnum = function(offence)
        return offence.primary_label.span.start_line
      end,
      col = function(offence)
        return offence.primary_label.span.start_column
      end,
    },
    severities = {
      Error = lint.severities.error,
      Warning = lint.severities.warning,
    },
    lines = true,
    offset = 0,
    source = 'selene',
  }),
}
