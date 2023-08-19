local lint = require('guard.lint')

return {
  cmd = 'clang-tidy',
  args = { '--quiet' },
  parse = lint.from_regex({
    source = 'clang-tidy',
    regex = ':(%d+):(%d+):%s+(%w+):%s+(.-)%s+%[(.-)%]',
    groups = { 'lnum', 'col', 'severity', 'message', 'code' },
    severities = {
      information = lint.severities.info,
      hint = lint.severities.info,
      note = lint.severities.style,
    },
  }),
}
