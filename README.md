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

-- call setup LAST
require('guard').setup({
    -- the only option for the setup function
    fmt_on_save = true,
})
```

Use `GuardFmt` to manually call format, use `GuardDisable` to diable auto format. and you can create
a keymap like

```lua
vim.keymap.set({'n','v'}, '<cmd>GuardFmt<CR>')
```

### Builtin tools

#### Formatter

- `lsp` use `vim.lsp.buf.format`
- `clang-format`
- `prettier`
- `rustfmt`
- `stylua`
- `golines`
- `black`

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

## Trobuleshooting

if guard does not auto format on save, run `checkhealth` first.

## License MIT
