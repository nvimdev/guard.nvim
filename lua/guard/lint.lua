local api = vim.api
---@diagnostic disable-next-line: deprecated
local uv = vim.version().minor >= 10 and vim.uv or vim.loop
local filetype = require('guard.filetype')
local spawn = require('guard.spawn').try_spawn
local ns = api.nvim_create_namespace('Guard')
local get_prev_lines = require('guard.util').get_prev_lines
local vd = vim.diagnostic

local function do_lint(buf)
  buf = buf or api.nvim_get_current_buf()
  if not filetype[vim.bo[buf].filetype] then
    return
  end
  local linters = filetype[vim.bo[buf].filetype].linter
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  local prev_lines = get_prev_lines(buf, 0, -1)
  vd.reset(ns, buf)

  coroutine.resume(coroutine.create(function()
    local results

    for _, lint in ipairs(linters) do
      lint = vim.deepcopy(lint)
      lint.args[#lint.args + 1] = fname
      lint.lines = prev_lines
      local data = spawn(lint)
      if #data > 0 then
        results = lint.parse(data, buf)
      end
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) or not results or #results == 0 then
        return
      end
      vd.set(ns, buf, results)
    end)
  end))
end

local debounce_timer = nil
local function register_lint(ft, extra)
  api.nvim_create_autocmd('FileType', {
    pattern = ft,
    callback = function(args)
      api.nvim_create_autocmd(vim.list_extend({ 'BufEnter' }, extra), {
        buffer = args.buf,
        callback = function(opt)
          if debounce_timer then
            debounce_timer:stop()
            debounce_timer = nil
          end
          debounce_timer = uv.new_timer()
          debounce_timer:start(500, 0, function()
            debounce_timer:stop()
            debounce_timer:close()
            debounce_timer = nil
            vim.schedule(function()
              do_lint(opt.buf)
            end)
          end)
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

local severities = {
  error = 1,
  warning = 2,
  info = 3,
  style = 4,
}

local from_opts = {
  offset = 1,
  source = nil,
  severities = severities,
}

local json_opts = {
  get_diagnostics = function(...)
    return vim.json.decode(...)
  end,
  attributes = {
    lnum = 'line',
    col = 'column',
    message = 'message',
    code = 'code',
    severity = 'severity',
  },
  lines = nil,
}

local function from_json(opts)
  opts = vim.tbl_deep_extend('force', from_opts, opts or {})
  opts = vim.tbl_deep_extend('force', json_opts, opts)

  return function(result, buf)
    local diags, offences = {}, {}

    if opts.lines then
      vim.tbl_map(function(line)
        offences[#offences + 1] = opts.get_diagnostics(line)
      end, vim.split(result, '\n', { trimempty = true }))
    else
      offences = opts.get_diagnostics(result)
    end

    vim.tbl_map(function(mes)
      diags[#diags + 1] = diag_fmt(
        buf,
        tonumber(mes[opts.attributes.lnum] - opts.offset),
        tonumber(mes[opts.attributes.col] - opts.offset),
        ('%s [%s]'):format(mes[opts.attributes.message], mes[opts.attributes.code]),
        opts.severities[mes[opts.attributes.severity]],
        opts.source
      )
    end, offences or {})

    return diags
  end
end

local regex_opts = {
  regex = nil,
  groups = { 'lnum', 'col', 'severity', 'code', 'message' },
}

local function from_regex(opts)
  opts = vim.tbl_deep_extend('force', from_opts, opts or {})
  opts = vim.tbl_deep_extend('force', regex_opts, opts)

  return function(result, buf)
    local diags, offences = {}, {}

    local lines = vim.split(result, '\n', { trimempty = true })

    for _, line in ipairs(lines) do
      local offence = {}

      local matches = { line:match(opts.regex) }

      -- regex matched
      if #matches == #opts.groups then
        for i = 1, #opts.groups do
          offence[opts.groups[i]] = matches[i]
        end

        offences[#offences + 1] = offence
      end
    end

    vim.tbl_map(function(mes)
      diags[#diags + 1] = diag_fmt(
        buf,
        tonumber(mes.lnum) - opts.offset,
        tonumber(mes.col) - opts.offset,
        ('%s [%s]'):format(mes.message, mes.code),
        opts.severities[mes.severity],
        opts.source
      )
    end, offences)

    return diags
  end
end

return {
  register_lint = register_lint,
  diag_fmt = diag_fmt,
  from_json = from_json,
  from_regex = from_regex,
  severities = severities,
}
