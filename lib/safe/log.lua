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
    function child.debug(fmt, ...)
        local prev = context
        context = ctx
        emit(M.DEBUG, fmt, ...)
        context = prev
    end
    function child.info(fmt, ...)
        local prev = context
        context = ctx
        emit(M.INFO, fmt, ...)
        context = prev
    end
    function child.warn(fmt, ...)
        local prev = context
        context = ctx
        emit(M.WARN, fmt, ...)
        context = prev
    end
    function child.error(fmt, ...)
        local prev = context
        context = ctx
        emit(M.ERROR, fmt, ...)
        context = prev
    end
    return child
end

return M
