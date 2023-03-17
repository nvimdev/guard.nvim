local uv, api = vim.loop, vim.api
local fmt = {}
local ctx = {}

fmt.__index = fmt
function fmt.__newindex(t, k, v)
  rawset(t, k, v)
end

local function safe_close(handle)
  if not uv.is_closing(handle) then
    uv.close(handle)
  end
end

function fmt:run(chunks, bufnr)
  if not self[bufnr] then
    return
  end

  local curr_changedtick = api.nvim_buf_get_changedtick(bufnr)
  if curr_changedtick ~= self[bufnr].initial_changedtick then
    vim.notify('current buffer is changed during the formatting', vim.log.levels.Error)
    if vim.fn.input('continue formatting? this will override curent buffer, y/n') ~= 'y' then
      return
    end
  end

  if not api.nvim_buf_is_valid(bufnr) then
    return
  end

  chunks = vim.split(table.concat(chunks, ''), '\n')

  if #chunks[#chunks] == 0 then
    table.remove(chunks, #chunks)
  end

  local old = vim.split(table.concat(self[bufnr].contents), '\n')
  if #old[#old] == 0 then
    old[#old] = nil
  end

  local function write_buffer()
    api.nvim_buf_set_lines(bufnr, 0, -1, false, chunks)
    vim.cmd('noautocmd silent write!')
  end

  if #old ~= #chunks then
    write_buffer()
  else
    local need_fmt = false
    for i, v in pairs(chunks) do
      local res = vim.diff(old[i], v)
      if #res ~= 0 then
        need_fmt = true
        break
      end
    end

    if need_fmt then
      write_buffer()
    end
  end

  self[bufnr] = nil
end

local function get_buf_contents(bufnr)
  local tbl = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local res = {}
  for _, text in pairs(tbl) do
    res[#res + 1] = text .. '\n'
  end
  return res
end

function fmt:new_spawn(buf)
  if not self[buf] then
    return
  end

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local stdin = uv.new_pipe(false)

  local chunks = {}
  local handle, pid
  handle, pid = uv.spawn(self[buf].cmd, {
    args = self[buf].args,
    stdio = { stdin, stdout, stderr },
  }, function(_, _)
    uv.read_stop(stdout)
    uv.read_stop(stderr)
    safe_close(handle)
    safe_close(stdout)
    safe_close(stderr)
    if self[buf].do_not_need_stdout then
      vim.schedule(function()
        local fd = uv.fs_open(vim.api.nvim_buf_get_name(buf), 'r', 438)
        if not fd then
          chunks = { '' }
        end
        local stat = uv.fs_fstat(fd)
        local data = uv.fs_read(fd, stat.size, 0)
        uv.fs_close(fd)
        chunks = { data }
        self:run(chunks, buf)
        -- NOTE: why we just use :edit command here? the edit will cause lsp/treesitter to reload
        -- if we use noautocmd edit, the lsp/treesitter will no longer work
      end)
    else
      if #chunks == 0 then
        return
      end
      vim.schedule(function()
        self:run(chunks, buf)
      end)
    end
  end)

  uv.read_start(stdout, function(err, data)
    assert(not err, err)
    if data then
      chunks[#chunks + 1] = data
    end
  end)

  uv.read_start(stderr, function(err, _)
    assert(not err, err)
  end)

  if self[buf].stdin then
    uv.write(stdin, self[buf].contents)
  end

  uv.shutdown(stdin, function()
    safe_close(stdin)
  end)
  self[buf].handle = handle
  self[buf].pid = pid
  self[buf].stdout = stdout
  self[buf].stderr = stderr
end

function fmt:check_finish(buf)
  return vim.schedule_wrap(function()
    if not self[buf] then
      return
    end

    local now = vim.loop.hrtime()
    if self[buf] then
      if self[buf].timer and not self[buf].timer:is_closing() then
        self[buf].timer:stop()
        self[buf].timer:close()
      end
      uv.read_stop(self[buf].stdout)
      uv.read_stop(self[buf].stderr)
      safe_close(self[buf].handle)
      safe_close(self[buf].stdout)
      safe_close(self[buf].stderr)
      uv.kill(self[buf].pid, 9)
      local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
      vim.notify(
        string.format(
          'timeout, check your config for %s: %s',
          ft,
          vim.inspect(require('easyformat.config')[ft])
        ),
        vim.log.levels.Error
      )
      self[buf] = nil
    end
  end)
end

function fmt:init(opt)
  local curr_changedtick = api.nvim_buf_get_changedtick(opt.bufnr)
  local init_time = vim.loop.hrtime()
  local timer = vim.loop.new_timer()
  if self[opt.bufnr] and self[opt.bufnr].initial_changedtick == curr_changedtick then
    return
  end

  self[opt.bufnr] = vim.tbl_extend('keep', {
    initial_changedtick = curr_changedtick,
    contents = get_buf_contents(opt.bufnr),
    init_time = init_time,
    timer = timer,
  }, opt)

  timer:start(require('easyformat.config').timeout, 0, self:check_finish(opt.bufnr))
  self:new_spawn(opt.bufnr)
end

return setmetatable(ctx, fmt)
