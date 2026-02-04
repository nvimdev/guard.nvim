---@class FmtConfigTable
---@field cmd string?
---@field args (string[]|fun(number):string[])?
---@field fname boolean?
---@field stdin boolean?
---@field fn function?
---@field events EventOption[]
---@field ignore_patterns string|string[]?
---@field ignore_error boolean?
---@field find string|string[]?
---@field env table<string, string>?
---@field timeout integer?
---@field health function?

---@alias FmtConfig FmtConfigTable|fun(): FmtConfigTable

---@class LintConfigTable
---@field cmd string?
---@field args (string[]|fun(number):string[])?
---@field fname boolean?
---@field stdin boolean?
---@field fn function?
---@field events EventOption[]
---@field parse function
---@field ignore_patterns string|string[]?
---@field ignore_error boolean?
---@field find string|string[]?
---@field env table<string, string>?
---@field timeout integer?
---@field health function?
---@field stderr boolean?
---@field ignore_exit_code boolean?

---@alias LintConfig LintConfigTable|fun(): LintConfigTable

---@alias AuOption vim.api.keyset.create_autocmd

---@class EventOption
---@field name string
---@field opt AuOption?
