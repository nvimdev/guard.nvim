# Advanced tips

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

## Writing advanced formatting logic

Guard exposes an api for writing advanced formatting logic:

```lua
require("guard.api").fmt_with({
    cmd              -- string: tool command
    args             -- table: command arugments
    fname            -- boolean: insert filename to args tail
    stdin            -- boolean: pass buffer contents into stdin
    timeout          -- integer
    env              -- table: environment variables passed to cmd (key value pair)

    fn               -- function: if fn is set other fields will not take effect
}, {
    buf              -- integer: buffer number
    range            -- table: {integer, integer} for range formatting
})
-- returns:
{
    result           -- table: list of formatted lines
    stderr           -- table: stderr output
    exit_code        -- integer: exit code
}
```

Note that fmt_with does not apply the format for you, YOU would have to apply it:

```lua
-- ...logic for checking exit code and stderr...
require("guard.api").apply_fmt({
    bufnr,          -- integer: buffer number
    prev_lines,     -- table: previous text
    new_lines,      -- table: format result
    srow,           -- integer: start row
    erow,           -- integer: end row
})
```

A bit of explanation: `prev_lines` if for using `vim.diff` to apply the minimal amount of changes to the buffer, if you choose to not pass this for some reason, you have to provide `erow` so that guard knows precisely what to replace.

Btw, you can get `prev_lines` using `require("guard.util").get_lines`
