# guard.nvim

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

Use `GuardFmt` to manually call format, use `GuardDisable` to diable auto format.
Create a keymap like so:

```lua
vim.keymap.set({'n','v'}, '<cmd>GuardFmt<cr>')
```

### Builtin Tools

#### Formatters

- `lsp` use `vim.lsp.buf.format`
- [black](https://github.com/psf/black)
- [cbfmt](https://github.com/lukas-reineke/cbfmt)
- [clang-format](https://www.kernel.org/doc/html/latest/process/clang-format.html)
- [djhtml](https://github.com/rtts/djhtml)
- [fish_indent](https://fishshell.com/docs/current/cmds/fish_indent.html)
- [fnfmlt](https://git.sr.ht/~technomancy/fnlfmt)
- [gofmt](https://pkg.go.dev/cmd/gofmt)
- [golines](https://pkg.go.dev/github.com/segmentio/golines)
- [google-java-format](https://github.com/google/google-java-format)
- [isort](https://github.com/PyCQA/isort)
- [mixformat](https://github.com/elixir-lang/elixir/)
- [pg_format](https://github.com/darold/pgFormatter)
- [prettier](https://github.com/prettier/prettier)
- [prettierd](https://github.com/fsouza/prettierd)
- [rubocop](https://github.com/rubocop/rubocop)
- [rustfmt](https://github.com/rust-lang/rustfmt)
- [shfmt](https://github.com/mvdan/sh)
- [stylua](https://github.com/JohnnyMorganz/StyLua)
- [swiftformat](https://github.com/nicklockwood/SwiftFormat)
- [swift-format](https://github.com/apple/swift-format)
- [sql-formatter](https://github.com/sql-formatter-org/sql-formatter)

Table format for custom tool:

```
{
    cmd              --string tool command
    args             --table command arugments
    fname            --string insert filename to args tail
    stdin            --boolean pass buffer contents into stdin
    timeout          --integer
    ignore_pattern   --table ignore run format when pattern match
    ignore_error     --when has lsp error ignore format

    --special
    fn       --function if fn is set other field will not take effect
}
```

#### Linter

- `clang-tidy`
- `Pylint`
- `rubocop`

## Troubleshooting

If guard does not auto format on save, run `checkhealth` first.

## License MIT
