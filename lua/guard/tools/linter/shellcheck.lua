return {
  cmd = 'shellcheck',
  args = { '--format', 'json1', '--external-sources' },
  stdin = true,
  parse = require('guard.lint').from_json({
    get_diagnostics = function(...)
      return vim.json.decode(...).comments
    end,
    -- https://github.com/koalaman/shellcheck/blob/master/shellcheck.1.md
    attributes = {
      severity = 'level',
    },
    source = 'shellcheck',
  }),
}
