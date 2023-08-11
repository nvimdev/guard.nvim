local M = {}

M.lsp = {
  fn = function(bufnr)
    vim.lsp.buf.format({ bufnr = bufnr })
  end,
}

M['clang-format'] = {
  cmd = 'clang-format',
  args = { '-style=file' },
  stdin = true,
}

M.prettier = {
  cmd = 'prettier',
  args = { '--stdin-filepath' },
  fname = true,
  stdin = true,
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

M.golines = {
  cmd = 'golines',
  args = { '--max-len=80' },
  stdin = true,
}

M.stylua = {
  cmd = 'stylua',
  args = { '-' },
  stdin = true,
}

M.black = {
  cmd = 'black',
  args = { '-' },
  stdin = true,
}

M.mixformat = {
  cmd = 'mix',
  args = {'format', '-', '--stdin-filename'},
  stdin = true,
  fname = true,
}

M.djhtml = {
  cmd = 'djhtml',
  args = { '-' },
  stdin = true
}

M.cbfmt = {
  cmd = 'cbfmt',
  args = { '--best-effort', '--stdin-filepath' },
  stdin = true,
  fname = true
}

M.shfmt = {
  cmd = 'shfmt',
  stdin = true,
}

M.isort = {
  cmd = 'isort',
  args = { '-' },
  stdin = true
}

M.prettierd = {
  cmd = 'prettierd',
  args = { '--stdin-filepath' },
  stdin = true,
  fname = true
}

M['sql-formatter'] = {
  cmd = 'sql-formatter',
  stdin = true
}

M.fish_indent = {
  cmd = 'fish_indent',
  stdin = true
}

M.swiftformat = {
  cmd = 'swiftformat',
  stdin = true
}

M.gofmt = {
  cmd = 'gofmt',
  stdin = true
}

M['google-java-format'] = {
  cmd = 'google-java-format',
  args = { '-' },
  stdin = true
}

return M
