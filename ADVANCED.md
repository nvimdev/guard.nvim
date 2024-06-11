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
local function prettierd_fmt(buf, range, acc)
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
end
```

We get the unformatted code, then call `vim.system` with 3 arguments

- the cmd, which is of the form `prettierd <file>`
- the option table, here we only specified that we wish to write to its stdin, but you can refer to `:h vim.system` for more options
- the `at_exit` function, which takes in a result table (again, check out `:h vim.system` for more details)

Now we can do our custom error handling, here we simply return if `prettierd` failed. But if it succeeded we replace the range with the formatted code and save the file.

Finally we write the unformatted code to stdin

```lua
local function prettierd_fmt(buf, range)
    -- previous code omitted

    handle:write(prev_lines)
    handle:write(nil)           -- closes stdin
    return coroutine.yield()    -- this returns either the error or the formatted code we returned earlier
end
```

Whoa la! Now we can tell guard to register our formatting function

```lua
ft("javascript"):fmt({
    fn = prettierd_fmt
})
```

## Take advantage of autocmd events

Guard exposes a `GuardFmt` user event that you can use. It is called both before formatting starts and after it is completely done. To differentiate between pre-format and post-format calls, a `data` table is passed.

```lua
-- for pre-format calls
data = {
    status = "pending", -- type: string, called whenever a format is requested
    using = {...}       -- type: table, whatever formatters you are using for this format action
}
-- for post-format calls
data = {
    status = "done",    -- type: string, only called on success
    results = {...}     -- type: table, formatted buffer text as a list of lines
}
-- or
data = {
    status = "failed"   -- type: string, buffer remain unchanged
    msg = "..."         -- type: string, currently only if buffer became invalid or changed during formatting
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

You can do the similar for your statusline plugin of choice as long as you "refresh" it on `GuardFmt`.
