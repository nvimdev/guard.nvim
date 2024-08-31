rockspec_format = '3.0'
package = 'guard.nvim'
version = 'scm-1'

test_dependencies = {
  'lua >= 5.1',
  'nlua',
}

source = {
  url = 'git://github.com/nvimdev/' .. package,
}

build = {
  type = 'builtin',
}
