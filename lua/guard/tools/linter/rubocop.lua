local lint = require('guard.lint')

return {
  cmd = 'bundle',
  args = { 'exec', 'rubocop', '--format', 'json', '--force-exclusion', '--stdin' },
  stdin = true,
  parse = lint.from_json({
    get_diagnostics = function(...)
      return vim.json.decode(...).files[1].offenses
    end,
    attributes = {
      lnum = 'location.line',
      col = 'location.column',
      code = 'cop_name',
    },
    severities = {
      convention = lint.severities.info,
      refactor = lint.severities.style,
      fatal = lint.severities.error,
    },
  }),
}
