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

-- use stylua to format lua files and no linter
ft('lua'):fmt('stylua')

-- use lsp to format first then use golines to format
ft('go'):fmt('lsp')
        :append('golines')
        :lint('golangci')

-- multiple files register
ft('typescript,javascript,typescriptreact'):fmt('prettier')

-- call setup LAST
require('guard').setup({
    -- the only options for the setup function
    fmt_on_save = true,
    -- Use lsp if no formatter was defined for this filetype
    lsp_as_default_formatter = false,
})
```

- Use `GuardFmt` to manually call format, when there is a visual selection only the selection is formatted.
- `GuardDisable` disables auto format for the current buffer, you can also `GuardDisable lua` or `GuardDisable 16` (the buffer number)
- Use `GuardEnable` to re-enable auto format, usage is the same as `GuardDisable`

### Builtin tools

#### Formatter

- `lsp` use `vim.lsp.buf.format`
- `clang-format`
- `prettier`
- `rustfmt`
- `fnlfmt`
- `stylua`
- `golines`
- `black`
- `rubocop`
- `mixformat`

Table format for custom tool:

```
{
    cmd              -- string: tool command
    args             -- table: command arugments
    fname            -- string: insert filename to args tail
    stdin            -- boolean: pass buffer contents into stdin
    timeout          -- integer
    ignore_pattern   -- table: ignore run format when pattern match
    ignore_error     -- boolean: when has lsp error ignore format
    find             -- string: format if the file is found in the lsp root dir

    --special
    fn       -- function: if fn is set other field will not take effect
}
```

#### Linter

- `clang-tidy`
- `Pylint`
- `rubocop`

## Troubleshooting

If guard does not auto format on save, run `checkhealth` first.

## License MIT
