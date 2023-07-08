local api = vim.api
local filetype = require('guard.filetype')
local spawn = require('guard.spawn').try_spawn
local ns = api.nvim_create_namespace('Guard')
local get_prev_lines = require('guard.util').get_prev_lines
local util = require('guard.util')
---@diagnostic disable-next-line: deprecated
local uv = vim.version().minor >= 10 and vim.uv or vim.loop

local function do_lint(buf)
  buf = buf or api.nvim_get_current_buf()
  if not filetype[vim.bo[buf].filetype] then
    return
  end
  local linters = filetype[vim.bo[buf].filetype].linter
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  local prev_lines = get_prev_lines(buf, 0, -1)
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  coroutine.resume(coroutine.create(function()
    local results

    for _, lint in ipairs(linters) do
      lint = vim.deepcopy(lint)
      lint.args[#lint.args + 1] = fname
      lint.cmd = util.get_lsp_root() or uv.cwd()
      lint.lines = prev_lines
      local data = spawn(lint)
      if #data > 0 then
        results = lint.output_fmt(data, buf)
      end
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) then
        return
      end
      for _, item in ipairs(results or {}) do
        api.nvim_buf_set_extmark(buf, ns, item.lnum - 1, 0, {
          virt_text = { { item.message, 'Diagnostic' .. vim.diagnostic.severity[item.severity] } },
          hl_mode = 'combine',
        })
      end
    end)
  end))
end

local function register_lint(ft, extra)
  api.nvim_create_autocmd('FileType', {
    pattern = ft,
    callback = function(args)
      api.nvim_create_autocmd(vim.list_extend({ 'BufEnter' }, extra), {
        buffer = args.buf,
        callback = function()
          do_lint(args.buf)
        end,
      })
    end,
  })
end

local function diag_fmt(buf, lnum, col, message, severity, source)
  return {
    bufnr = buf,
    col = col,
    end_col = col,
    end_lnum = lnum,
    lnum = lnum,
    message = message,
    namespace = ns,
    severity = severity,
    source = source,
  }
end

return {
  register_lint = register_lint,
  diag_fmt = diag_fmt,
}
