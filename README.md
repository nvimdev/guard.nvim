[![LuaRocks](https://img.shields.io/luarocks/v/xiaoshihou514/guard.nvim?logo=lua&color=green)](https://luarocks.org/modules/xiaoshihou514/guard.nvim)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/nvimdev/guard.nvim/test.yml?label=tests)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/nvimdev/guard.nvim/ci.yml?label=lint)

Async formatting and linting utility for neovim `0.10+`.

## Features

- Async and blazingly fast
- Builtin support for popular formatters and linters
- Minimal API allowing for full customization
- Light-weight

## TLDR

[`help guard.nvim-tldr`](#tldr)

- Install with your favorite package manager

```
nvimdev/guard.nvim
```

- Register formatters:

```lua
local ft = require('guard.filetype')
ft('c'):fmt('clang-format')
```

[demo](https://github.com/user-attachments/assets/3160f979-6683-4288-870d-2447ee445431)

- Register linters

```lua
local ft = require('guard.filetype')
ft('lua'):lint('selene')
```

[demo](https://github.com/user-attachments/assets/2ee2fdaa-42b2-41b3-80ad-26a53bf16809)

- They can also be chained together:

```lua
local ft = require('guard.filetype')
ft('haskell'):fmt('ormolu')
             :lint('hlint')
```

- Formatters and linters can also be chained:

```lua
local ft = require('guard.filetype')
ft('python'):fmt('isort')
            :append('black')
            :lint('mypy')
            :append('mypyc')
            :append('dmypy')
```

- You can register the same formatter for multiple filetypes:

```lua
local ft = require('guard.filetype')
ft('typescript,javascript,typescriptreact'):fmt('prettier')
```

- Lint all your files with `codespell`

```lua
-- this does not work with formatters
ft('*'):lint('codespell')
```

- Custom formatters:

```lua
-- always use 4 spaces for c files
ft('c'):fmt({
    cmd = "clang-format",
    args = { "--style={IndentWidth: 4}" },
    stdin = true,
})
```

## Usage

[`help guard.nvim-usage`](#usage)

Some presets can be configured via `vim.g.guard_config`

```lua
-- defaults
vim.g.guard_config = {
    -- format on write to buffer
    fmt_on_save = true,
    -- use lsp if no formatter was defined for this filetype
    lsp_as_default_formatter = false,
    -- whether or not to save the buffer after formatting
    save_on_fmt = true,
    -- automatic linting
    auto_lint = true,
    -- how frequently can linters be called
    lint_interval = 500
    -- show diagnostic after format done
    refresh_diagnostic = true,
}
```

Here are all the `Guard` subcommands

|        Name        |                                       Desc                                       |
| :----------------: | :------------------------------------------------------------------------------: |
|     Guard fmt      | Manually call format, also works with visual mode (best effort range formatting) |
|     Guard lint     |                            Manually request for lint                             |
|  Guard enable-fmt  |                 Turns auto formatting on for the current buffer                  |
| Guard disable-fmt  |                 Turns auto formatting off for the current buffer                 |
| Guard enable-lint  |                     Turns linting on for the current buffer                      |
| Guard disable-lint |                     Turns linting off for the current buffer                     |

## Further configuration

You can easily create your own configuration that's not in `guard-collection`, see [`help guard.nvim-creating-new-configurations`](./CUSTOMIZE.md).

For more niche use cases, [`help guard.nvim-advanced-tips`](./ADVANCED.md) demonstrates how to:

- Write your own formatting logic using the `fn` field.
- Write your own linting logic using the `fn` field.
- Leverage guard's autocmds to create a formatting status indicator.
- Creating a dynamic formatter that respects neovom tab/space settings.

```{.include}
CUSTOMIZE.md
ADVANCED.md
```
