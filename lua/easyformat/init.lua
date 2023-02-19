local api, lsp, fn = vim.api, vim.lsp, vim.fn
local ef = {}
local fmt = require('easyformat.format')

local function get_lsp_client()
  local current_buf = api.nvim_get_current_buf()
  local clients = lsp.get_active_clients({ buffer = current_buf })
  if next(clients) == nil then
    return nil
  end

  for _, client in pairs(clients) do
    local fts = client.config.filetypes
    if
      client.server_capabilities.documentFormattingProvider
      and vim.tbl_contains(fts, vim.bo.filetype)
    then
      return client
    end
  end
end

local function searcher(match, bufnr)
  if not match then
    return true
  end

  local fname = api.nvim_buf_get_name(bufnr)
  if #fname == 0 then
    fname = vim.loop.cwd()
  end
  local res =
    vim.fs.find(match, { upward = true, path = fname, stop = vim.env.HOME, type = 'file' })
  if #res ~= 0 then
    return true
  end
  vim.notify('[EasyFormat] Does not find ' .. match .. ' in local', vim.log.levels.WARN)
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
  local conf = ef.config[vim.bo[buf].filetype]

  if conf.ignore_patterns and ignored(buf, conf.ignore_patterns) then
    return
  end

  if #vim.diagnostic.get(buf, { severity = vim.diagnostic.severity.Error }) ~= 0 then
    return
  end

  if searcher(conf.find, buf) then
    fmt:init(vim.tbl_extend('keep', conf, { bufnr = buf }))
  end

  if conf.hook then
    conf.hook()
  end

  if conf.lsp and get_lsp_client() then
    lsp.buf.format({ async = true })
  end
end

local function register_command()
  api.nvim_create_user_command('EasyFormat', function()
    do_fmt()
  end, {})
end

local function register_event(fts)
  local group = api.nvim_create_augroup('EasyFormat with lsp and third tools', { clear = true })
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

local function executable_validate(config)
  local pass = true
  for key, item in pairs(config) do
    if key ~= 'fmt_on_save' and fn.executable(item.cmd) == 0 then
      vim.notify('[EasyFormat] cmd ' .. item.cmd .. ' not executable', vim.log.levels.WARN)
      pass = false
      break
    end
  end
  return pass
end

function ef.setup(config)
  ef.config = config
  if not executable_validate(config) then
    return
  end

  if config.fmt_on_save then
    local fts = vim.tbl_keys(config)
    fts = vim.tbl_filter(function(k)
      return k ~= 'fmt_on_save'
    end, fts)

    register_event(fts)
  end

  register_command()
end

return ef
