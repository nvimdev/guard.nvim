---@class FmtConfigTable
---@field cmd string?
---@field args string[]?
---@field fname boolean?
---@field stdin boolean?
---@field fn function?
---@field ignore_patterns string|string[]?
---@field ignore_error boolean?
---@field find string|string[]?
---@field env table<string, string>?
---@field timeout integer?

---@alias FmtConfig FmtConfigTable|fun(): FmtConfigTable

---@class LintConfigTable
---@field cmd string?
---@field args string[]?
---@field fname boolean?
---@field stdin boolean?
---@field fn function?
---@field parse function
---@field ignore_patterns string|string[]?
---@field ignore_error boolean?
---@field find string|string[]?
---@field env table<string, string>?
---@field timeout integer?

---@alias LintConfig LintConfigTable|fun(): LintConfigTable
