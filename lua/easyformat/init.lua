local api = vim.api
local ef = {}
local fmt = require('easyformat.format')

local function searcher(match, bufnr)
  if not match or #match == 0 then
    return true
  end

  local fname = api.nvim_buf_get_name(bufnr)
  fname = #fname == 0 and vim.loop.cwd() or fname
  local res =
    vim.fs.find(match, { upward = true, path = fname, stop = vim.env.HOME, type = 'file' })
  if #res ~= 0 then
    return true
  end

  print('[EasyFormat] Does not find ' .. match .. ' in local')
  return false
end

local function ignored(buf, patterns)
  local fname = api.nvim_buf_get_name(buf)
  if #fname == 0 then
    return false
  end

  for _, pattern in pairs(patterns) do
    if fname:find(pattern) then
      return true
    end
  end
  return false
end

local function do_fmt(buf)
  buf = buf or api.nvim_get_current_buf()
  local configs = require('easyformat.config')
  local conf = configs[vim.bo[buf].filetype]
  if not conf then
    return
  end

  conf = vim.deepcopy(conf)

  if conf.ignore_patterns and ignored(buf, conf.ignore_patterns) then
    return
  end

  if conf.before then
    conf.before()
  end

  --ignore when have error diagnostics
  if #vim.diagnostic.get(buf, { severity = 1 }) ~= 0 then
    return
  end

  if searcher(conf.find, buf) then
    if conf.fname then
      conf.args[#conf.args + 1] = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
    end
    fmt:init(vim.tbl_extend('keep', conf, { bufnr = buf }))
  end
end

local function register_command()
  api.nvim_create_user_command('EasyFormat', function()
    do_fmt()
  end, {})
end

local function register_event(fts)
  local group = api.nvim_create_augroup('EasyFormat', { clear = true })
  local function bufwrite(bufnr)
    api.nvim_create_autocmd('BufWritePre', {
      group = group,
      buffer = bufnr,
      callback = function(opt)
        do_fmt(opt.buf)
      end,
    })
  end

  api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = fts,
    callback = function(opt)
      bufwrite(opt.buf)
    end,
    desc = 'EasyFormat',
  })
end

function ef.setup(opt)
  if opt.fmt_on_save then
    local configs = require('easyformat.config')
    local fts = vim.tbl_keys(configs)
    register_event(fts)
  end

  register_command()
end

return ef
