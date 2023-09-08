local lint = require('guard.lint')

return {
  cmd = 'pylint',
  args = { '--from-stdin', '--output-format', 'json' },
  stdin = true,
  parse = lint.from_json({
    attributes = {
      severity = 'type',
      code = 'symbol',
    },
    severities = {
      -- https://pylint.readthedocs.io/en/stable/user_guide/usage/output.html
      convention = lint.severities.info,
      refactor = lint.severities.info,
      informational = lint.severities.info,
      fatal = lint.severities.error,
    },
    source = 'pylint',
  }),
}
