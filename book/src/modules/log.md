# safe.log

Structured logging with injectable output and timestamps. Supports level gating, context tags, and child loggers.

```lua
local log = require("safe.log")
```

## Source

```lua
--[[
  log.lua — Structured logging with injectable output and timestamps.
  Supports level gating, context tags, and child loggers.
]]

local M = {}

local string_format = string.format
local os_date = os.date
local select = select

-- Levels (higher = less verbose)
M.DEBUG = 10
M.INFO = 20
M.WARN = 30
M.ERROR = 40
M.NONE = 100

local level_names = {
    [M.DEBUG] = "DEBUG",
    [M.INFO] = "INFO",
    [M.WARN] = "WARN",
    [M.ERROR] = "ERROR",
}

local current_level = M.INFO
local context = nil

local output_fn = function(msg)
    io.write(msg .. "\n")
end

local timestamp_fn = function()
    return os_date("%Y-%m-%dT%H:%M:%S")
end

--- Set minimum log level.
--- @param level number
function M.set_level(level)
    current_level = level
end

--- Get current log level.
--- @return number
function M.get_level()
    return current_level
end

--- Set output handler function.
--- @param fn function receives a single string argument
function M.set_output(fn)
    output_fn = fn
end

--- Set timestamp function.
--- @param fn function returns a timestamp string
function M.set_timestamp(fn)
    timestamp_fn = fn
end

--- Set context tag for log messages.
--- @param ctx string|nil
function M.set_context(ctx)
    context = ctx
end

--- Get current context tag.
--- @return string|nil
function M.get_context()
    return context
end

local function emit(level, fmt, ...)
    if level < current_level then
        return
    end
    local msg
    if select("#", ...) > 0 then
        msg = string_format(fmt, ...)
    else
        msg = fmt
    end
    local ts = timestamp_fn()
    local level_name = level_names[level] or "UNKNOWN"
    if context then
        output_fn(string_format("[%s] [%s] [%s] %s", ts, level_name, context, msg))
    else
        output_fn(string_format("[%s] [%s] %s", ts, level_name, msg))
    end
end

function M.debug(fmt, ...)
    emit(M.DEBUG, fmt, ...)
end

function M.info(fmt, ...)
    emit(M.INFO, fmt, ...)
end

function M.warn(fmt, ...)
    emit(M.WARN, fmt, ...)
end

function M.error(fmt, ...)
    emit(M.ERROR, fmt, ...)
end

--- Create a child logger with a preset context.
--- @param ctx string context tag
--- @return table logger with debug/info/warn/error methods
function M.with_context(ctx)
    local child = {}
    local function with_ctx(level, fmt, ...)
        local prev = context
        context = ctx
        local ok, err = pcall(emit, level, fmt, ...)
        context = prev
        if not ok then
            error(err, 3)
        end
    end
    function child.debug(fmt, ...)
        with_ctx(M.DEBUG, fmt, ...)
    end
    function child.info(fmt, ...)
        with_ctx(M.INFO, fmt, ...)
    end
    function child.warn(fmt, ...)
        with_ctx(M.WARN, fmt, ...)
    end
    function child.error(fmt, ...)
        with_ctx(M.ERROR, fmt, ...)
    end
    return child
end

return M
```

## Log Levels

| Constant | Value | Purpose |
|----------|-------|---------|
| `log.DEBUG` | 10 | Detailed diagnostic information |
| `log.INFO` | 20 | General operational messages (default) |
| `log.WARN` | 30 | Potential issues |
| `log.ERROR` | 40 | Errors that need attention |
| `log.NONE` | 100 | Suppress all output |

Messages are emitted only when their level is **>=** the current level.

## Functions

### `log.set_level(level)` / `log.get_level()`

Control the minimum log level:

```lua
log.set_level(log.DEBUG)  -- show everything
log.set_level(log.WARN)   -- only warnings and errors
```

### `log.set_output(fn)` / `log.set_timestamp(fn)`

Inject custom output and timestamp handlers for testing or integration:

```lua
-- Send logs to a table for testing
local captured = {}
log.set_output(function(msg) captured[#captured + 1] = msg end)

-- Fixed timestamp for deterministic tests
log.set_timestamp(function() return "2024-01-01T00:00:00" end)
```

### `log.set_context(ctx)` / `log.get_context()`

Tag all subsequent log messages with a context string:

```lua
log.set_context("myapp")
log.info("Started")  --> [2024-01-01T00:00:00] [INFO] [myapp] Started
```

### `log.debug(fmt, ...)` / `log.info(fmt, ...)` / `log.warn(fmt, ...)` / `log.error(fmt, ...)`

Emit log messages with `string.format`-style formatting:

```lua
log.info("Server started on port %d", 8080)
log.warn("Cache miss rate: %.1f%%", 12.5)
```

When no varargs are passed, the format string is used as-is (no `string.format` call), so literal percent signs are safe: `log.info("CPU at 100%")`.

### `log.with_context(ctx)`

Create a child logger with a preset context. The child temporarily sets
the context for each message and restores the parent context afterward
— even if the output function throws.

```lua
local db_log = log.with_context("database")
db_log.info("Connection pool size: %d", 10)
--> [TS] [INFO] [database] Connection pool size: 10

-- Parent context is unaffected
log.info("Still the parent context")
```

## Patterns

### Testing with Injectable Output

```lua
local captured = {}
log.set_output(function(msg) captured[#captured + 1] = msg end)
log.set_timestamp(function() return "TS" end)
log.set_level(log.DEBUG)

log.info("hello %s", "world")
assert(captured[1]:find("hello world"))
```

### Module State is Shared

Since Lua caches modules in `package.loaded`, all `require("safe.log")` calls return the same table. Level and context changes are visible globally.

## Known Limitations

- **Shared global state**: Level, context, output function, and timestamp function are module-level upvalues. Multiple `require` calls share the same state.
- **Format string errors propagate**: If the format string expects more
  arguments than provided, `string.format` throws — this propagates
  through the log call.
- **Child context is pcall-protected**: The `with_context` child logger uses `pcall` to ensure context is restored even when the output function errors. The error is re-raised after cleanup.
