# guard.nvim

Async formatting and linting utility for neovim `0.10+`.

## Features

- Blazingly fast
- Async using coroutine and luv spawn
- Builtin support for popular formatters and linters
- Easy configuration for custom tools
- Light-weight

## Usage

Installation for lazy.nvim

```lua
{
    "nvimdev/guard.nvim",
    -- Builtin configuration, optional
    dependencies = {
        "nvimdev/guard-collection",
    },
}
```

Guard is configured as follows:

```lua
local ft = require('guard.filetype')

-- Assuming you have guard-collection
ft('lang'):fmt('format-tool-1')
          :append('format-tool-2')
          :env(env_table)
          :lint('lint-tool-1')
          :extra(extra_args)

-- Call setup() LAST!
require('guard').setup({
    -- Choose to format on every write to a buffer
    fmt_on_save = true,
    -- Use lsp if no formatter was defined for this filetype
    lsp_as_default_formatter = false,
    -- By default, Guard writes the buffer on every format
    -- You can disable this by setting:
    -- save_on_fmt = false,
})
```

- Use `GuardFmt` to manually call format, when there is a visual selection only the selection is formatted. **NOTE**: Regional formatting just sends your selection to the formatter, if there's not enough context incoherent formatting might occur (e.g. indent being erased)
- `GuardDisable` disables auto format for the current buffer, you can also `GuardDisable 16` (the buffer number)
- Use `GuardEnable` to re-enable auto format, usage is the same as `GuardDisable`

Format c files with clang-format and lint with clang-tidy:

```lua
ft('c'):fmt('clang-format')
       :lint('clang-tidy')
```

Or use lsp to format lua files first, then format with stylua, then lint with selene:

```lua
ft('lua'):fmt('lsp')
        :append('stylua')
        :lint('selene')
```

Register multiple filetypes to a single linter or formatter:

```lua
ft('typescript,javascript,typescriptreact'):fmt('prettier')
```

Lint all your files with `codespell`

```lua
-- NB: this does not work with formatters
ft('*'):lint('codespell')
```

You can also easily create your own configuration that's not in `guard-collection`, see [CUSTOMIZE.md](./CUSTOMIZE.md).

For more niche use cases, [ADVANCED.md](./ADVANCED.md) demonstrates how to:

- Write your own formatting logic using the `fn` field
- Write your own linting logic using the `fn` field
- leverage guard's autocmds to create a status line component

```{.include}
CUSTOMIZE.md
ADVANCED.md
```
