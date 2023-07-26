## guard.nvim

Async formatting and linting utility for neovim. 

## Features

- Blazingly fast
- Async using coroutine and luv spawn
- Builtin support for popular formatters and linters
- Light-weight

## Usage

Use any plugin manager you like. Guard is configured in format like this:

```lua
ft('c'):fmt('tool-1')
       :append('tool-2')
       :lint('lint-tool-1')
       :append('lint-tool-2')
```

if the tool is not supported, you will have to pass in a table instead of a string, see [here](https://github.com/nvimdev/guard.nvim/tree/main/lua%2Fguard%2Ftools) for some examples, more info below.

```lua
local ft = require('guard.filetype')

-- use clang-format and clang-tidy for c files
ft('c'):fmt('clang-format')
       :lint('clang-tidy')

-- use prettier to format jsx and js files with no linter configured
ft('javascript,javascriptreact'):fmt('prettier')

-- use lsp to format first then use golines to format
ft('go'):fmt('lsp')
        :append('golines')
        :lint('golangci')

-- call setup LAST
require('guard').setup({
    -- the only option for the setup function
    fmt_on_save = true,
})
```

Optionally, you can setup this plugin more verbosely, like so:

```lua
require('guard').setup({
  fmt_on_save = true,
  ft = {
    go = {
      fmt = { { cmd = 'gofmt', stdin = true } },
    },
    py = { lint = { 'pylint' } },
  },
})
```

- Use `GuardFmt` to manually call format, if you have a visual selection, only the selection would be formatted.
- `GuardDisable` disables auto-formatting. To disable it for certain buffers, use `GuardDisable {bufnr}` (0 for current buf). You can also use `GuardDisable {filetype}` to disable auto-format for a specific filetype. If you call `GuardFmt` manually, the buffer would still get formatted.
- `GuardEnable` re-enables the disabled auto-format, with the same argument as `GuardDisable`.

### Builtin tools

#### Formatter

- `lsp` (which uses `vim.lsp.buf.format`)
- `clang-format`
- `prettier`
- `rustfmt`
- `stylua`
- `golines`
- `black`
- `rubocop`

Table format for custom formatter:

```
{
    cmd              -- string: tool command
    args             -- table: command arugments
    fname            -- string: insert filename to args tail
    stdin            -- boolean: pass buffer contents into stdin
    timeout          -- integer
    ignore_pattern   -- table: ignore run format when pattern match
    ignore_error     -- when has lsp error ignore format

    --special
    fn       -- function: if fn is set, other field will not take effect
}
```

#### Linter

- `clang-tidy`
- `Pylint`
- `rubocop`

## Troubleshooting

If guard does not auto format on save, run `checkhealth` first.

## License MIT
