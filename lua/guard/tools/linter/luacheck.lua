local lint = require('guard.lint')

return {
  cmd = 'luacheck',
  args = { '--formatter', 'plain', '--codes', '-', '--filename' },
  fname = true,
  stdin = true,
  parse = lint.from_regex({
    regex = '(%d+):(%d+):%s%((%a)(%w+)%) (.+)',
    severities = {
      E = lint.severities.error,
      W = lint.severities.warning,
    },
    source = 'luacheck',
  }),
}
