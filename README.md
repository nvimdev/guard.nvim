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

## Config

```lua
fmt_on_save = true -- default is true when is true it will run format on BufWritePre
--filetype config
filetype = {
    cmd  -- string type the third party format command.
    args -- table type command arguments.
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
builtin support filetypes

- c cpp `clang-format`
- rust  `rustfmt`
- lua   `stylua`
- go    `golines`
- js/ts/react `prettier`

`require('easyformat.config').get_config` is an export function that you can use it go get the
default configs the param is filetypes can be `string | table`

you can use this code to get the default config then override it

```lua
local get_config = require('easyformat.config').get_config
local config = get_config('cpp')
-- then you can override this tool config and pass it to setup function
require('easyformat').setup({
    cpp = config
})
```

## Command

 use a command `EasyFormat` to format file.

## Example configs

- usage in my [config](https://github.com/glepnir/nvim)

```lua
  local get_config = require('easyformat.config').get_config
  local configs =
    get_config({ 'c', 'cpp', 'lua', 'rust', 'go', 'javascriptreact', 'typescriptreact' })
  local params = vim.tbl_extend('keep', {
    fmt_on_save = true,
  }, configs)
  require('easyformat').setup(params)
```

## License MIT
