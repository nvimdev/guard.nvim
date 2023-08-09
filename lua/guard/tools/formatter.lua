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
  args = { '-filename' },
  stdin = true,
  fname = true
}

M.isort = {
  cmd = 'isort',
  args = { '-', '--stdout', '--filename' },
  stdin = true,
  fname = true
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

return M
