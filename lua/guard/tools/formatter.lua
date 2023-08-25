local M = {}

M.lsp = {
  fn = function(bufnr, range)
    vim.lsp.buf.format({ bufnr = bufnr, range = range, async = true })
  end,
}

M.black = {
  cmd = 'black',
  args = { '--quiet', '-' },
  stdin = true,
}

M.cbfmt = {
  cmd = 'cbfmt',
  args = { '--best-effort', '--stdin-filepath' },
  stdin = true,
  fname = true,
}

M['clang-format'] = {
  cmd = 'clang-format',
  stdin = true,
}

M.djhtml = {
  cmd = 'djhtml',
  args = { '-' },
  stdin = true,
}

M.fish_indent = {
  cmd = 'fish_indent',
  stdin = true,
}

M.fnlfmt = {
  cmd = 'fnlfmt',
  args = { '-' },
  stdin = true,
}

M.gofmt = {
  cmd = 'gofmt',
  stdin = true,
}

M.golines = {
  cmd = 'golines',
  args = { '--max-len=80' },
  stdin = true,
}

M['google-java-format'] = {
  cmd = 'google-java-format',
  args = { '-' },
  stdin = true,
}

M.isort = {
  cmd = 'isort',
  args = { '-' },
  stdin = true,
}

M.latexindent = {
  cmd = 'latexindent',
  stdin = true,
}

M.mixformat = {
  cmd = 'mix',
  args = { 'format', '-', '--stdin-filename' },
  stdin = true,
  fname = true,
}

M.pg_format = {
  cmd = 'pg_format',
  stdin = true,
}

M.prettier = {
  cmd = 'prettier',
  args = { '--stdin-filepath' },
  fname = true,
  stdin = true,
}

M.prettierd = {
  cmd = 'prettierd',
  args = { '--stdin-filepath' },
  stdin = true,
  fname = true,
}

M.rubocop = {
  cmd = 'bundle',
  args = { 'exec', 'rubocop', '-A', '-f', 'quiet', '--stderr', '--stdin' },
  stdin = true,
  fname = true,
}

M.rustfmt = {
  cmd = 'rustfmt',
  args = { '--edition', '2021', '--emit', 'stdout' },
  stdin = true,
}

M.shfmt = {
  cmd = 'shfmt',
  stdin = true,
}

M.stylua = {
  cmd = 'stylua',
  args = { '-' },
  stdin = true,
}

M.swiftformat = {
  cmd = 'swiftformat',
  stdin = true,
}

M['swift-format'] = {
  cmd = 'swift-format',
  stdin = true,
}

M['sql-formatter'] = {
  cmd = 'sql-formatter',
  stdin = true,
}

return M
