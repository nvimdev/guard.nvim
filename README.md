# easyformat.nvim
a simply and powerful plugin make format easy in neovim with third party command and lsp format

<center>
<img src="https://user-images.githubusercontent.com/41671631/218993459-aeaf79fe-c77f-4d4f-a820-57e1a6464af4.gif" width=40% height=40%>
</center>

## Features

- async
- fast
- minimalist and light weight

## Install

- Lazy.nvim

```lua
require('lazy').setup({
 {'glepnir/easyformat.nvim', ft = {filetypes}, config = function()
    require('easyformat').setup({})
 end},
})
```

- packer.nvim

```lua
use({
 {'glepnir/easyformat.nvim', ft = {filetypes}, config = function()
    require('easyformat').setup({})
 end},
})
```

## Options

```lua
fmt_on_save = true -- default is true when is true it will run format on BufWritePre
```

## Format tools config

set a new config for filetype

```lua
local configs = require('easyformat.config')
configs.filetype = {
    cmd  -- string type the third party format command.
    args -- table type command arguments.
    fname -- boolean when it's true it will auto insert current buffername to args
    stdin -- boolean type when is true will send the buffer contents to stdin
    ignore_patterns --table type when file name match one of it will ignore format
    find  -- string type search the config file that command used. if not find will not format
    before -- function type a hook run before format
}
```

Examples you can `clang-format` for c file like this

```
    c = {
      cmd = 'clang-format',
      args = { '-style=file', vim.api.nvim_buf_get_name(0) },
      ignore_patterns = { 'neovim/*' },
      find = '.clang-format',
      stdin = false,
      before = function()
        print('run before format')
      end
    },
```
## Use built-in tools config

builtin filetypes config

- c cpp `clang-format`
- rust  `rustfmt`
- lua   `stylua`
- go    `golines`
- js/ts/react `prettier`

if you want edit some field of default tool config you can do it like this

```lua
local configs = require('easyformat.config')
configs.lua = {
    ignore_patterns = { '%pspec', 'neovim/*' },
}
```

if you want use mulitples default configs you can use the `configs.use_default` function lie

```lua
configs.use_default({'javascript', 'javascriptreact', 'typescript','typescriptreact'})
```


## Command

 use a command `EasyFormat` to format file.

## Example configs

- usage in my [config](https://github.com/glepnir/nvim)

```lua
  local configs = require('easyformat.config')
  configs.lua = {
    ignore_patterns = { '%pspec', 'neovim/*' },
  }
  configs.c = {
    ignore_patterns = { 'neovim/*' },
  }
  configs.use_default({
    'cpp',
    'go',
    'rust',
    'javascriptreact',
  })
  require('easyformat').setup({
    fmt_on_save = true,
  })
```

## License MIT
