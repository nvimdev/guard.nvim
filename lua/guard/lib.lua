local M = {}

-- Result type for error handling
local Result = {}
Result.__index = Result
M.Result = Result

function Result.ok(value)
  return setmetatable({ ok = true, value = value, error = nil }, Result)
end

function Result.err(error)
  return setmetatable({ ok = false, value = nil, error = error }, Result)
end

-- Chain operations on Result
function Result:and_then(func)
  if not self.ok then
    return self
  end

  local status, result = pcall(func, self.value)
  if not status then
    return Result.err(result)
  end

  -- If func returns a Result, return it directly
  if getmetatable(result) == Result then
    return result
  end

  return Result.ok(result)
end

-- Map over the success value
function Result:map(func)
  if not self.ok then
    return self
  end

  local status, result = pcall(func, self.value)
  if not status then
    return Result.err(result)
  end

  return Result.ok(result)
end

-- Map over the error value
function Result:map_err(func)
  if self.ok then
    return self
  end

  local status, result = pcall(func, self.error)
  if not status then
    return Result.err(result)
  end

  return Result.err(result)
end

-- Match pattern for Result
function Result:match(handlers)
  if self.ok and handlers.ok then
    return handlers.ok(self.value)
  elseif not self.ok and handlers.err then
    return handlers.err(self.error)
  end
end

-- Get value or default
function Result:unwrap_or(default)
  return self.ok and self.value or default
end

-- Get value or compute default
function Result:unwrap_or_else(func)
  if self.ok then
    return self.value
  end
  return func(self.error)
end

-- Get value or panic
function Result:unwrap()
  if self.ok then
    return self.value
  end
  error(vim.inspect(self.error))
end

-- Get error or panic
function Result:unwrap_err()
  if not self.ok then
    return self.error
  end
  error('called `unwrap_err()` on an `ok` value')
end

-- Check if is ok
function Result:is_ok()
  return self.ok
end

-- Check if is error
function Result:is_err()
  return not self.ok
end

-- Async utilities
local Async = {}
M.Async = Async

-- Error types
Async.Error = {
  COMMAND_FAILED = 'COMMAND_FAILED',
  TIMEOUT = 'TIMEOUT',
  CANCELLED = 'CANCELLED',
  INVALID_STATE = 'INVALID_STATE',
  COROUTINE_ERROR = 'COROUTINE_ERROR',
}

-- Create structured error
function Async.error(type, message, details)
  return {
    type = type,
    message = message,
    details = details or {},
    timestamp = os.time(),
  }
end

-- Wrap a function to return a Result
function Async.wrap(func)
  return function(...)
    local args = { ... }
    local status, result = pcall(func, unpack(args))
    if status then
      return Result.ok(result)
    else
      return Result.err(result)
    end
  end
end

-- Try/catch style error handling
function Async.try(func)
  return Async.wrap(func)()
end

-- Enhanced vim.system wrapper with timeout and cancellation
function Async.system(cmd, opts)
  opts = opts or {}
  return function(callback)
    local progress_data = {}
    local error_data = {}
    local stderr_callback = opts.stderr

    -- Setup options
    local system_opts = vim.deepcopy(opts)

    -- Capture stderr for progress if requested
    if stderr_callback then
      system_opts.stderr = function(_, data)
        if data then
          table.insert(error_data, data)
          stderr_callback(_, data)
        end
      end
    end

    -- Call vim.system with proper error handling
    vim.system(cmd, system_opts, function(obj)
      -- Success is 0 exit code
      local success = obj.code == 0

      if success then
        callback(Result.ok({
          stdout = obj.stdout,
          stderr = obj.stderr,
          code = obj.code,
          signal = obj.signal,
          progress = progress_data,
        }))
      else
        callback(Result.err({
          message = 'Command failed with exit code: ' .. obj.code,
          stdout = obj.stdout,
          stderr = obj.stderr,
          code = obj.code,
          signal = obj.signal,
          progress = progress_data,
        }))
      end
    end)
  end
end

-- Create an async context that tracks running operations
function Async.context()
  local ctx = {
    operations = {},
    cancelled = false,
  }

  function ctx:run(promise)
    if self.cancelled then
      return Result.err(Async.error(Async.Error.CANCELLED, 'Context was cancelled'))
    end

    local cancel_fn
    local wrapped = function(callback)
      if self.cancelled then
        callback(Result.err(Async.error(Async.Error.CANCELLED, 'Context was cancelled')))
        return
      end

      cancel_fn = promise(function(result)
        self.operations[promise] = nil
        callback(result)
      end)

      if cancel_fn then
        self.operations[promise] = cancel_fn
      end
    end

    return wrapped
  end

  function ctx:cancel()
    self.cancelled = true
    for _, cancel_fn in pairs(self.operations) do
      if type(cancel_fn) == 'function' then
        cancel_fn()
      end
    end
    self.operations = {}
  end

  return ctx
end

-- Await a promise and return Result
function Async.await(promise)
  local co = coroutine.running()
  if not co then
    return Result.err(
      Async.error(Async.Error.INVALID_STATE, 'Cannot await outside of an async function')
    )
  end

  promise(function(result)
    vim.schedule(function()
      local ok, err = coroutine.resume(co, result)
      if not ok then
        vim.notify(
          string.format('Coroutine error: %s', debug.traceback(co, err)),
          vim.log.levels.ERROR
        )
      end
    end)
  end)

  return coroutine.yield()
end

-- Create an async function
function Async.async(func)
  return function(...)
    local args = { ... }
    local co = coroutine.create(function()
      return Async.try(function()
        return func(unpack(args))
      end)
    end)

    local function step(...)
      local ok, value = coroutine.resume(co, ...)
      if not ok then
        vim.schedule(function()
          vim.notify(
            string.format('Async error: %s', debug.traceback(co, value)),
            vim.log.levels.ERROR
          )
        end)
      end
      return ok, value
    end

    step()
  end
end

-- Create a callback-based async function
function Async.callback(func)
  return function(...)
    local args = { ... }
    return function(callback)
      coroutine.wrap(function()
        local result = Async.try(function()
          return func(unpack(args))
        end)
        callback(result)
      end)()
    end
  end
end

-- Run multiple promises in parallel
function Async.all(promises)
  return function(callback)
    if #promises == 0 then
      callback(Result.ok({}))
      return
    end

    local results = {}
    local completed = 0
    local has_error = false

    for i, promise in ipairs(promises) do
      promise(function(result)
        if has_error then
          return
        end

        if result:is_err() then
          has_error = true
          callback(result)
          return
        end

        results[i] = result.value
        completed = completed + 1

        if completed == #promises then
          callback(Result.ok(results))
        end
      end)
    end
  end
end

-- Run multiple promises and collect all results (including errors)
function Async.all_settled(promises)
  return function(callback)
    if #promises == 0 then
      callback(Result.ok({}))
      return
    end

    local results = {}
    local completed = 0

    for i, promise in ipairs(promises) do
      promise(function(result)
        results[i] = result
        completed = completed + 1

        if completed == #promises then
          callback(Result.ok(results))
        end
      end)
    end
  end
end

-- Race multiple promises
function Async.race(promises)
  return function(callback)
    local resolved = false

    for _, promise in ipairs(promises) do
      promise(function(result)
        if not resolved then
          resolved = true
          callback(result)
        end
      end)
    end
  end
end

-- Create a promise that resolves after a delay
function Async.delay(ms)
  return function(callback)
    local timer = assert(vim.uv.new_timer())
    timer:start(ms, 0, function()
      timer:stop()
      timer:close()
      vim.schedule(function()
        callback(Result.ok(nil))
      end)
    end)
  end
end

-- Convenience functions
function Async.resolve(value)
  return function(callback)
    vim.schedule(function()
      callback(Result.ok(value))
    end)
  end
end

function Async.reject(error)
  return function(callback)
    vim.schedule(function()
      callback(Result.err(error))
    end)
  end
end

-- Pipe multiple async operations
function Async.pipe(...)
  local operations = { ... }

  return function(initial_value)
    return function(callback)
      local function process(index, value)
        if index > #operations then
          callback(Result.ok(value))
          return
        end

        local op = operations[index]
        op(value)(function(result)
          if result:is_err() then
            callback(result)
          else
            process(index + 1, result.value)
          end
        end)
      end

      process(1, initial_value)
    end
  end
end

return M
