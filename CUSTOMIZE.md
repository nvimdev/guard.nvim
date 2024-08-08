# Creating new configurations
A tool is specified as follows:

```lua
{
    -- specify an executable
    cmd              -- string: tool command
    args             -- string[]: command arguments
    fname            -- boolean: insert filename to args tail
    stdin            -- boolean: pass buffer contents into stdin

    -- or provide your own logic
    fn               -- function: write your own logic for formatting / linting, more in ADVANCED.md

    -- running condition
    ignore_patterns  -- string|string[]: don't run formatter when pattern match against file name
    ignore_error     -- boolean: when has lsp error ignore format
    find             -- string|string[]: format if the file is found in the lsp root dir

    -- misc
    env              -- table<string, string>?: environment variables passed to cmd (key value pair)
    timeout          -- integer

    -- special
    parse            -- function: linter only, parses linter output to neovim diagnostic
}
```

guard also tries to require them if you have `guard-collection`.

## Examples: formatters
Let's see a few formatters from `guard-collection`:

```lua
rustfmt = {
  cmd = 'rustfmt',
  args = { '--edition', '2021', '--emit', 'stdout' },
  stdin = true,
}
```
NB: Sometimes you may wish to run multiple formatters sequentially, this is only possible if you have `stdin` set ([or if you are using fn](./ADVANCED.md)) for all your formatters. This design is intentional for keeping buffer contents "valid". However, if you only wish to use one formatter, then letting the tool itself to do the IO _may be_ faster.

```lua
eslint_d = {
  cmd = 'npx',
  args = { 'eslint_d', '--fix-to-stdout', '--stdin', '--stdin-filename' },
  fname = true,
  stdin = true,
}

black = {
  cmd = 'black',
  args = { '--quiet', '-' },
  stdin = true,
}
```

## Examples: linters
In addition to all the formatter fields, a linter needs to provide a `parse` function that takes the linter output and turns it into neovim diagnostics (`:h vim.Diagnostic`).

This sounds very cumbersome! Fortunately guard provides some api to make it smoother.

Let's see an example: clang-tidy
```bash
clang-tidy /tmp/test.c
```
<details>
<summary>Output</summary>

```
Error while trying to load a compilation database:
Could not auto-detect compilation database for file "/tmp/test.c"
No compilation database found in /tmp or any parent directory
fixed-compilation-database: Error while opening fixed database: No such file or directory
json-compilation-database: Error while opening JSON database: No such file or directory
Running without flags.
1 warning generated.
/tmp/test.c:6:20: warning: Division by zero [clang-analyzer-core.DivideZero]
/tmp/test.c:6:20: warning: Division by zero [clang-analyzer-core.DivideZero]
    6 |     printf("%d", x / y);
      |                  ~~^~~
/tmp/test.c:5:5: note: 'y' initialized to 0
    5 |     int y = 0;
      |     ^~~~~
/tmp/test.c:6:20: note: Division by zero
    6 |     printf("%d", x / y);
      |                  ~~^~~

```
</details>


In this case we are most interested in this line:

```
/tmp/test.c:6:20: warning: Division by zero [clang-analyzer-core.DivideZero]
```
And we can identify some elements:
```
lnum = 6
col = 20
severity = warning
message = Division by zero
code = clang-analyzer-core.DivideZero
```
The following regex will give us the elements, and we just need them in a table
```lua
local xs = { line:match(":(%d+):(%d+):%s+(%w+):%s+(.-)%s+%[(.-)%]") }
local lookup = { ... } -- omitted
local result = {
    lnum = xs[1],
    col = xs[2],
    -- The severity is a string, but neovim expects `:h vim.diagnostic.severity`
    severity = lookup[xs[3]],
    message = xs[4],
    code = xs[5]
}
```

This pattern is encapsulated by `require("guard.lint").from_regex`

```lua
clang_tidy = {
  cmd = 'clang-tidy',
  args = { '--quiet' },
  parse = lint.from_regex({
    source = 'clang-tidy',
    regex = ':(%d+):(%d+):%s+(%w+):%s+(.-)%s+%[(.-)%]',
    groups = { 'lnum', 'col', 'severity', 'message', 'code' },
    severities = {
      information = lint.severities.info,
      hint = lint.severities.info,
      note = lint.severities.style,
    },
  }),
}
```
Another example:
```lua
ktlint = {
  cmd = 'ktlint',
  args = { '--log-level=error' },
  fname = true,
  parse = lint.from_regex({
    source = 'ktlint',
    regex = ':(%d+):(%d+): (.+) %((.-)%)',
    groups = { 'lnum', 'col', 'message', 'code' },
    -- severities defaults to info, warning, error, style
  }),
}
```
Figuring out the patterns can take a while, so for tools that support json output, it's usually easier to take the json, put it into a table, and get the respective key.

This pattern is encapsulated by `require("guard.lint").from_json`, an example:
```bash
cat /tmp/test.py | pylint --from-stdin true --output-format json
```
<details>
<summary>Output</summary>
    
```
[
    {
        "type": "convention",
        "module": "true",
        "obj": "",
        "line": 89,
        "column": 0,
        "endLine": null,
        "endColumn": null,
        "path": "true",
        "symbol": "line-too-long",
        "message": "Line too long (125/100)",
        "message-id": "C0301"
    },
    {
        "type": "convention",
        "module": "true",
        "obj": "",
        "line": 215,
        "column": 0,
        "endLine": null,
        "endColumn": null,
        "path": "true",
        "symbol": "line-too-long",
        "message": "Line too long (108/100)",
        "message-id": "C0301"
    }
]

```
</details>

```lua
pylint = {
  cmd = 'pylint',
  args = { '--from-stdin', '--output-format', 'json' },
  stdin = true,
  parse = lint.from_json({
    attributes = {
      severity = 'type',
      code = 'symbol',
    },
    severities = {
      convention = lint.severities.info,
      refactor = lint.severities.info,
      informational = lint.severities.info,
      fatal = lint.severities.error,
    },
    source = 'pylint',
  }),
}
```

Another example:
```lua
ruff = {
  cmd = 'ruff',
  args = { '-n', '-e', '--output-format', 'json', '-', '--stdin-filename' },
  stdin = true,
  fname = true,
  parse = lint.from_json({
    attributes = {
      severity = 'type',
      -- if the json is very complex, pass a function
      lnum = function(js)
        return js['location']['row']
      end,
      col = function(js)
        return js['location']['column']
      end,
    },
    severities = {
      E = lint.severities.error, -- pycodestyle errors
      -- other severities omitted
    },
    source = 'ruff',
  }),
}
```
