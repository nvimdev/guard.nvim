local api = vim.api
local filetype = require('guard.filetype')
local spawn = require('guard.spawn').spawn
local ns = api.nvim_create_namespace('Guard')

local function do_lint(buf)
  buf = buf or api.nvim_get_current_buf()
  if not filetype[vim.bo[buf].filetype] then
    return
  end
  local linters = filetype[vim.bo[buf].filetype].linter
  linters = vim.tbl_map(function(item)
    local prefix = 'guard.tools.linter.'
    if type(item) == 'string' and require(prefix .. item) then
      return require(prefix .. item)
    else
      return item
    end
  end, linters)
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))

  coroutine.resume(coroutine.create(function()
    local results = {}

    for _, lint in ipairs(linters) do
      lint.args[#lint.args + 1] = fname
      local result = spawn(lint)
      if #result > 0 then
        results[#results + 1] = lint.parser(result, buf, ns)
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

local function follow_diangostic_request()
  api.nvim_create_autocmd('LspRequest', {
    callback = function(args)
      local request = args.data.request
      print(vim.inspect(request))
    end,
  })
end

return {
  do_lint = do_lint,
  follow_diangostic_request = follow_diangostic_request,
}
