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
