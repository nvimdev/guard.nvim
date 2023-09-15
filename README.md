# guard.nvim

Async formatting and linting utility for neovim.

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
    -- the only options for the setup function
    fmt_on_save = true,
    -- Use lsp if no formatter was defined for this filetype
    lsp_as_default_formatter = false,
})
```

- Use `GuardFmt` to manually call format, when there is a visual selection only the selection is formatted. **NOTE**: Regional formatting just sends your selection to the formatter, if there's not enough context incoherent formatting might occur (e.g. indent being erased)
- `GuardDisable` disables auto format for the current buffer, you can also `GuardDisable 16` (the buffer number)
- Use `GuardEnable` to re-enable auto format, usage is the same as `GuardDisable`

### Example Configuration

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

### Custom Configuration

Easily setup your custom tool if not in the defaults or you do not want guard-collection bundled:

```
{
    cmd              -- string: tool command
    args             -- table: command arugments
    fname            -- boolean: insert filename to args tail
    stdin            -- boolean: pass buffer contents into stdin
    timeout          -- integer
    ignore_pattern   -- table: don't run formatter when pattern match against file name
    ignore_error     -- boolean: when has lsp error ignore format
    find             -- string: format if the file is found in the lsp root dir
    env              -- table: environment variables passed to cmd (key value pair)

    -- special
    parse            -- function: used to parse linter output to neovim diagnostic
    fn               -- function: if fn is set other fields will not take effect
}
```

For example, format your assembly with [asmfmt](https://github.com/klauspost/asmfmt):

```lua
ft('asm'):fmt({
    cmd = 'asmfmt',
    stdin = true
})
```

Consult the [builtin tools](https://github.com/nvimdev/guard-collection/tree/main/lua/guard-collection) if needed.

### Supported Tools

See [here](https://github.com/nvimdev/guard-collection) for an exhaustive list.
