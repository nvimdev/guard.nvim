return {
  cmd = 'hadolint',
  args = { '--no-fail', '--format=json' },
  stdin = true,
  parse = require('guard.lint').from_json({
    attributes = {
      severity = 'level',
    },
    source = 'hadolint',
  }),
}
