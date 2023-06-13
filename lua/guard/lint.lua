local api = vim.api
local filetype = require('guard.filetype')
local spawn = require('guard.spawn').try_spawn
local ns = api.nvim_create_namespace('Guard')
local get_prev_lines = require('guard.util').get_prev_lines

local function do_lint(buf)
  buf = buf or api.nvim_get_current_buf()
  if not filetype[vim.bo[buf].filetype] then
    return
  end
  local linters = filetype[vim.bo[buf].filetype].linter
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  local prev_lines = get_prev_lines(buf)
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  coroutine.resume(coroutine.create(function()
    local results = {}

    for _, lint in ipairs(linters) do
      lint = vim.deepcopy(lint)
      if lint.stdin then
        lint.lines = prev_lines
      else
        lint.args[#lint.args + 1] = fname
      end
      local result = spawn(lint)
      if #result > 0 then
        results[#results + 1] = lint.output_fmt(result, buf, ns)
      end
    end

    vim.schedule(function()
      for _, item in ipairs(results) do
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

return {
  register_lint = register_lint,
}
