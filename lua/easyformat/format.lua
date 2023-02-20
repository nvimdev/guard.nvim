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
    vim.cmd('noautocmd write')
  end

  if #old ~= #chunks then
    write_buffer()
    return
  end

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

  self.handle, self.pid = uv.spawn(self[buf].cmd, {
    args = self[buf].args,
    stdio = { stdin, stdout, stderr },
  }, function(_, _)
    uv.read_stop(stdout)
    uv.read_stop(stderr)
    safe_close(self.handle)
    safe_close(stdout)
    safe_close(stderr)
    vim.schedule(function()
      self:run(chunks, buf)
    end)
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
    print(vim.inspect(self[buf].contents))
    uv.write(stdin, self[buf].contents)
  end

  uv.shutdown(stdin, function()
    safe_close(stdin)
  end)
end

function fmt:init(opt)
  local curr_changedtick = api.nvim_buf_get_changedtick(opt.bufnr)
  if self[opt.bufnr] and self[opt.bufnr].initial_changedtick == curr_changedtick then
    return
  end

  self[opt.bufnr] = vim.tbl_extend('keep', {
    initial_changedtick = curr_changedtick,
    contents = get_buf_contents(opt.bufnr),
  }, opt)

  self:new_spawn(opt.bufnr)
end

return setmetatable(ctx, fmt)
