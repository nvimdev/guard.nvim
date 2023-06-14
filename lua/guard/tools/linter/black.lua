return {
  cmd = 'black',
  args = { '-' },
  stdin = true,
  out_fmt = function(result)
    print(vim.inspect(result))
  end,
}
