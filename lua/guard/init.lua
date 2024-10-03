return {
  setup = function(opt)
    vim.deprecate(
      'Calling require("guard").setup',
      'vim.g.guard_config',
      '1.1.0',
      'guard.nvim',
      true
    )
    vim.g.guard_config = vim.tbl_extend('force', {
      fmt_on_save = true,
      lsp_as_default_formatter = false,
      save_on_fmt = true,
    }, opt or {})
  end,
}
