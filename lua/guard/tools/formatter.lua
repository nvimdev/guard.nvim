local M = {}

M['clang-format'] = {
  cmd = 'clang-format',
  args = { '-style=file' },
  stdin = true,
}

M.prettier = {
  cmd = 'prettier',
  args = { '--stdin-filepath' },
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
  before = function()
    vim.lsp.buf.code_action({ context = { only = { 'source.organizeImports' } }, apply = true })
  end,
}

M.stylua = {
  cmd = 'stylua',
  args = { '-' },
  stdin = true,
}

return M
