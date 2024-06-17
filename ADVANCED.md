# Advanced tips

## Special case formatting logic

With the introduction of `vim.system` in neovim 0.10, it is now easy to write custom formatting logic. Let's work through an example of how you could do so.

`prettierd` does not work well with guard because of it's error mechanism. Guard follows a reasonable unix standard when it comes to determining exit status, that is, assuming the program would exit with non-zero exit code and print some reasonable error message in stderr:

```lua
if exit_code ~= 0 and num_stderr_chunks ~= 0 then
    -- failed
else
    -- success
end
```

However, `prettierd` prints error messages to stdout, so guard will fail to detect an error and proceed to replace your code with its error message :cry:

But fear not! You can create your custom logic by passing a function in the config table, let's do this step by step:

```lua
local function prettierd_fmt(buf, range, acc)
    local co = assert(coroutine.running())
end
```

Guard runs the format function in a coroutine so as not to block the UI, to achieve what we want we have to interact with the current coroutine.

We can now go on to mimic how we would call `prettierd` on the cmdline:

```
cat test.js | prettierd test.js
```

```lua
-- previous code omitted
local handle = vim.system({ "prettierd", vim.api.nvim_buf_get_name(buf) }, {
	stdin = true,
}, function(result)
	if result.code ~= 0 then
		-- "returns" the error
		coroutine.resume(co, result)
	else
		-- "returns" the result
		coroutine.resume(co, result.stdout)
	end
end)
```

We get the unformatted code, then call `vim.system` with 3 arguments

- the cmd, which is of the form `prettierd <file>`
- the option table, here we only specified that we wish to write to its stdin, but you can refer to `:h vim.system` for more options
- the `at_exit` function, which takes in a result table (again, check out `:h vim.system` for more details)

Now we can do our custom error handling, here we simply return if `prettierd` failed. But if it succeeded we replace the range with the formatted code and save the file.

Finally we write the unformatted code to stdin

```lua
-- previous code omitted
handle:write(acc)
handle:write(nil)           -- closes stdin
return coroutine.yield()    -- this returns either the error or the formatted code we returned earlier
```

Whoa la! Now we can tell guard to register our formatting function

```lua
ft("javascript"):fmt({
    fn = prettierd_fmt
})
```

[demo](https://github.com/xiaoshihou514/guard.nvim/assets/108414369/56dd35d4-8bf6-445a-adfd-8786fb461021)

You can always refer to [spawn.lua](https://github.com/nvimdev/guard.nvim/blob/main/lua/guard/spawn.lua).

## Custom logic with linters

`clippy-driver` is a linter for rust, because it prints diagnostics to stderr, you cannot just specify it the usual way. But guard allows you to pass a custom function, which would make it work :)

Let's start by doing some imports:

```lua
local ft = require("guard.filetype")
local lint = require("guard.lint")
```

The lint function is a simple modification of the one in [spawn.lua](https://github.com/nvimdev/guard.nvim/blob/main/lua/guard/spawn.lua).

```lua
local function clippy_driver_lint(acc)
    local co = assert(coroutine.running())
    local handle = vim.system({ "clippy-driver", "-", "--error-format=json", "--edition=2021" }, {
    stdin = true,
    }, function(result)
        -- wake coroutine on exit, omit error checking
        coroutine.resume(co, result.stderr)
    end)
    -- write contents to stdin and close it
    handle:write(acc)
    handle:write(nil)
    -- sleep until awakened after process finished
    return coroutine.yield()
end
```

We register it via guard:

```lua
ft("rust"):lint({
    fn = clippy_driver_lint,
    stdin = true,
    parse = clippy_diagnostic_parse, -- TODO!
})
```

To write the lint function, we inspect the output of `clippy-driver` when called with the arguments above:

<details>
<summary>full output</summary>

```
❯ cat test.rs
fn main() {
    let _ = 'a' .. 'z';
}
❯ cat test.rs | clippy-driver - --error-format=json --edition=2021
{"$message_type":"diagnostic","message":"almost complete ascii range","code":{"code":"clippy::almost_complete_range","explanation":null},"level":"warning","spans":[{"file_name":"<anon>","byte_start":24,"byte_end":34,"line_start":2,"line_end":2,"column_start":13,"column_end":23,"is_primary":true,"text":[{"text":"    let _ = 'a' .. 'z';","highlight_start":13,"highlight_end":23}],"label":null,"suggested_replacement":null,"suggestion_applicability":null,"expansion":null}],"children":[{"message":"for further information visit https://rust-lang.github.io/rust-clippy/master/index.html#almost_complete_range","code":null,"level":"help","spans":[],"children":[],"rendered":null},{"message":"`#[warn(clippy::almost_complete_range)]` on by default","code":null,"level":"note","spans":[],"children":[],"rendered":null},{"message":"use an inclusive range","code":null,"level":"help","spans":[{"file_name":"<anon>","byte_start":28,"byte_end":30,"line_start":2,"line_end":2,"column_start":17,"column_end":19,"is_primary":true,"text":[{"text":"    let _ = 'a' .. 'z';","highlight_start":17,"highlight_end":19}],"label":null,"suggested_replacement":"..=","suggestion_applicability":"MaybeIncorrect","expansion":null}],"children":[],"rendered":null}],"rendered":"warning: almost complete ascii range\n --> <anon>:2:13\n  |\n2 |     let _ = 'a' .. 'z';\n  |             ^^^^--^^^^\n  |                 |\n  |                 help: use an inclusive range: `..=`\n  |\n  = help: for further information visit https://rust-lang.github.io/rust-clippy/master/index.html#almost_complete_range\n  = note: `#[warn(clippy::almost_complete_range)]` on by default\n\n"}
{"$message_type":"diagnostic","message":"this comparison involving the minimum or maximum element for this type contains a case that is always true or always false","code":{"code":"clippy::absurd_extreme_comparisons","explanation":null},"level":"error","spans":[{"file_name":"<anon>","byte_start":43,"byte_end":56,"line_start":3,"line_end":3,"column_start":8,"column_end":21,"is_primary":true,"text":[{"text":"    if 42 > i32::MAX {}","highlight_start":8,"highlight_end":21}],"label":null,"suggested_replacement":null,"suggestion_applicability":null,"expansion":null}],"children":[{"message":"because `i32::MAX` is the maximum value for this type, this comparison is always false","code":null,"level":"help","spans":[],"children":[],"rendered":null},{"message":"for further information visit https://rust-lang.github.io/rust-clippy/master/index.html#absurd_extreme_comparisons","code":null,"level":"help","spans":[],"children":[],"rendered":null},{"message":"`#[deny(clippy::absurd_extreme_comparisons)]` on by default","code":null,"level":"note","spans":[],"children":[],"rendered":null}],"rendered":"error: this comparison involving the minimum or maximum element for this type contains a case that is always true or always false\n --> <anon>:3:8\n  |\n3 |     if 42 > i32::MAX {}\n  |        ^^^^^^^^^^^^^\n  |\n  = help: because `i32::MAX` is the maximum value for this type, this comparison is always false\n  = help: for further information visit https://rust-lang.github.io/rust-clippy/master/index.html#absurd_extreme_comparisons\n  = note: `#[deny(clippy::absurd_extreme_comparisons)]` on by default\n\n"}
{"$message_type":"diagnostic","message":"aborting due to 1 previous error; 1 warning emitted","code":null,"level":"error","spans":[],"children":[],"rendered":"error: aborting due to 1 previous error; 1 warning emitted\n\n"}
```

</details>

That's a lot of output! But we can see three main blocks: the first two diagnostics and the last one an overview. We only need the first two:

```lua
local clippy_diagnostic_parse =
	parse = lint.from_json({
		get_diagnostics = function(line)
			local json = vim.json.decode(line)
            -- ignore overview json which does not have position info
			if not vim.tbl_isempty(json.spans) then
				return json
			end
		end,
        lines = true,
		attributes = { ... } -- TODO
    })
```

Now our diagnostics are transformed into a list of json, we just need to get the attributes we need: the positions, the message and the error level. That's what the attributes field does, it extracts them from the json table:

```lua
attributes = {
    -- it is json turned into a lua table
    lnum = function(it)
        -- clippy has really weird indexes
        return math.ceil(tonumber(it.spans[1].line_start) / 2)
    end,
    lnum_end = function(it)
        return math.ceil(tonumber(it.spans[1].line_end) / 2)
    end,
    code = function(it)
        return it.code.code
    end,
    col = function(it)
        return it.spans[1].column_start
    end,
    col_end = function(it)
        return it.spans[1].column_end
    end,
    severity = "level",     -- "it.level"
    message = "message",    -- "it.message"
},
```

Done! :start2:

![image](https://github.com/xiaoshihou514/guard.nvim/assets/108414369/f9137b5a-ae69-494f-9f5b-b6044ae63c86)

## Take advantage of autocmd events

Guard exposes a `GuardFmt` user event that you can use. It is called both before formatting starts and after it is completely done. To differentiate between pre-format and post-format calls, a `data` table is passed.

```lua
-- for pre-format calls
data = {
    status = "pending", -- type: string, called whenever a format is requested
    using = {...}       -- type: table, formatters that are going to run
}
-- for post-format calls
data = {
    status = "done",    -- type: string, only called on success
}
-- or
data = {
    status = "failed"   -- type: string, buffer remain unchanged
    msg = "..."         -- type: string, reason for failure
}
```

A handy use case for it is to retrieve formatting status, here's a bare-bones example:

```lua
local is_formatting = false
_G.guard_status = function()
    -- display icon if auto-format is enabled for current buffer
    local au = vim.api.nvim_get_autocmds({
        group = "Guard",
        buffer = 0,
    })
    if filetype[vim.bo.ft] and #au ~= 0 then
        return is_formatting and "" or ""
    end
    return ""
end
-- sets a super simple statusline when entering a buffer
vim.cmd("au BufEnter * lua vim.opt.stl = [[%f %m ]] .. guard_status()")
-- update statusline on GuardFmt event
vim.api.nvim_create_autocmd("User", {
    pattern = "GuardFmt",
    callback = function(opt)
        -- receive data from opt.data
        is_formatting = opt.data.status == "pending"
        vim.opt.stl = [[%f %m ]] .. guard_status()
    end,
})
```

[demo](https://github.com/xiaoshihou514/guard.nvim/assets/108414369/339ff4ff-288c-49e4-8ab1-789a6175d201)

You can do the similar for your statusline plugin of choice as long as you "refresh" it on `GuardFmt`.
