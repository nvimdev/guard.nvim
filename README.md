## guard.nvim

Asynchronous formatting and lint checking plug-ins, I personally don't like the way that use fake 
lsp to client to do formatting and lint checking. Accept lsp request or notify then invoke tool then
get result and send back. Why add a process in the middle, There is a proverb in China called
**Paint a snake with feet** and don't blindly praise lsp.It's getting bloated and unwieldy.

## Features

- Async using coroutine and luv spawn
- Support config mulitple tools for format or lint on buffer 
- Light-weight

## Setup

use any plugin manager you like then call setup

```lua
--config must before this line
require('guard').setup({})
```

## Config Options

- `fmt_on_save`     auto format when save file

command `GuardFmt` for command use, use `GuardDisable` to diable auto format.

## Usage

an example usage 

```lua
local ft = require('guard.filetype')
local c = ft('c')
c:fmt('clang-format')
c:lint('clang-tidy')
ft('lua'):fmt('stylua')
ft('go'):fmt('lsp'):append('golines')
--note setup must be last line
require('guard').setup()
```

first import `guard.filetype` module then call it to register filetype,then use chain call to
register format or tool config by using `fmt` and `append` function.type of them is `table` or
`string` if you want use the builin config just pass string if you want use a custom config pass table.

### Builtin tools

#### Formatter

- `lsp` use `vim.lsp.buf.format`
- `clang-format`
- `prettier`
- `rustfmt`
- `stylua`
- `golines`

table format for custom tool 

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

## Trobule

if guard do nothing when save file run `checkhealth` first.


## License MIT
