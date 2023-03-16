local M = {}

function M.get_config(fts)
  local prettier = {
    cmd = 'prettier',
    args = { '--stdin-filepath', vim.api.nvim_buf_get_name(0) },
    stdin = true,
  }

  local configs = {
    c = {
      cmd = 'clang-format',
      args = { '-style=file', vim.api.nvim_buf_get_name(0) },
      ignore_patterns = { 'neovim/*' },
      find = '.clang-format',
      stdin = false,
    },
    cpp = {
      cmd = 'clang-format',
      args = { '-style=file', vim.api.nvim_buf_get_name(0) },
      ignore_patterns = { 'neovim/*' },
      find = '.clang-format',
      stdin = false,
    },
    rust = {
      cmd = 'rustfmt',
      args = {},
      stdin = true,
    },
    go = {
      cmd = 'golines',
      args = { '--max-len=80', vim.api.nvim_buf_get_name(0) },
      stdin = false,
      before = function()
        vim.lsp.buf.code_action({ context = { only = { 'source.organizeImports' } }, apply = true })
      end,
    },
    lua = {
      cmd = 'stylua',
      ignore_patterns = { '%pspec', 'neovim/*' },
      find = '.stylua.toml',
      args = { '-' },
      stdin = true,
    },
    typescript = prettier,
    typescriptreact = prettier,
    javascript = prettier,
    javascriptreact = prettier,
  }

  if type(fts) == 'string' and configs[fts] then
    return { fts = configs[fts] }
  end

  local res = {}
  for _, ft in ipairs(fts) do
    res[ft] = configs[ft]
  end
  return res
end

return M
