# guard.nvim

[![LuaRocks](https://img.shields.io/luarocks/v/xiaoshihou514/guard.nvim?logo=lua&color=green)](https://luarocks.org/modules/xiaoshihou514/guard.nvim)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/nvimdev/guard.nvim/test.yml?label=tests)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/nvimdev/guard.nvim/ci.yml?label=lint)

Async formatting and linting utility for neovim `0.10+`.

## Features

- Blazingly fast
- Async using coroutine and luv spawn
- Builtin support for popular formatters and linters
- Easy configuration for custom tools
- Light-weight

## Usage

For rocks.nvim

```vim
Rocks install guard.nvim
```

For lazy.nvim

```lua
{
    "nvimdev/guard.nvim",
    -- lazy load by ft
    ft = { "lua", "c", "markdown" },
    -- Builtin configuration, optional
    dependencies = {
        "nvimdev/guard-collection",
    },
}
```

To register formatters and linters:

```lua
local ft = require('guard.filetype')

-- Assuming you have guard-collection
-- Put this in your ftplugin/lang.lua to lazy load guard
ft('lang'):fmt('format-tool-1')
          :append('format-tool-2')
          :env(env_table)
          :lint('lint-tool-1')
          :extra(extra_args)

-- change this anywhere in your config, these are the defaults
vim.g.guard_config = {
    -- format on write to buffer
    fmt_on_save = true,
    -- use lsp if no formatter was defined for this filetype
    lsp_as_default_formatter = false,
    -- whether or not to save the buffer after formatting
    save_on_fmt = true,
}
```

- Use `Guard fmt` to manually call format, when there is a visual selection only the selection is formatted. **NOTE**: Regional formatting just sends your selection to the formatter, if there's not enough context incoherent formatting might occur (e.g. indent being erased)
- `Guard disable` disables auto format for the current buffer, you can also `Guard disable 16` (the buffer number)
- Use `Guard enable` to re-enable auto format, usage is the same as `Guard disable`

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

- Write your own formatting logic using the `fn` field.
- Write your own linting logic using the `fn` field.
- Leverage guard's autocmds to create a formatting status indicator.
- Creating a dynamic formatter that respects neovom tab/space settings.

```{.include}
CUSTOMIZE.md
ADVANCED.md
```
