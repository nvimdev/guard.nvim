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

return M
