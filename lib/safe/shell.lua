--[[
  shell.lua — Safe shell execution with escaping and argument arrays.
  Never builds commands from raw strings. Swappable executor for testing.
]]

local M = {}

local type = type
local tostring = tostring
local string_format = string.format
local string_find = string.find
local string_gsub = string.gsub
local table_concat = table.concat
local error = error

--- Normalize os.execute return values across Lua 5.1 and 5.2+.
--- Lua 5.1: returns exit code (number)
--- Lua 5.2+: returns true/nil, "exit"/"signal", code
--- Exposed as M._normalize_exit for testing.
local function normalize_exit(...)
    local n = select("#", ...)
    if n >= 3 then
        local ok, _reason, code = ...
        return ok == true, code
    end
    -- Lua 5.1: single return value
    local code = ...
    if type(code) == "number" then
        return code == 0, code
    end
    return code == true, code and 0 or 1
end

--- Single-quote shell escaping.
--- Wraps argument in single quotes, escaping any embedded single quotes.
--- @param arg string
--- @return string escaped
function M.escape(arg)
    return "'" .. string_gsub(tostring(arg), "'", "'\\''") .. "'"
end

--- Escape an array of arguments and join with spaces.
--- @param args table array of string arguments
--- @return string escaped and joined
function M.escape_args(args)
    local parts = {}
    for i = 1, #args do
        parts[i] = M.escape(tostring(args[i]))
    end
    return table_concat(parts, " ")
end

--- Validate that a program name contains no shell metacharacters.
--- @param name string program name
--- @return boolean ok, string|nil err
function M.validate_program(name)
    if type(name) ~= "string" then
        return false, string_format("program name must be string, got %s", type(name))
    end
    if name == "" then
        return false, "program name must not be empty"
    end
    if string_find(name, "[;&|`$%(%){}%[%]<>!#~]") then
        return false, string_format("program name contains shell metacharacters: %s", name)
    end
    return true, nil
end

--- Validate that all args are strings.
--- @param args table
--- @return boolean ok, string|nil err
function M.validate_args(args)
    if type(args) ~= "table" then
        return false, string_format("args must be table, got %s", type(args))
    end
    for i = 1, #args do
        if type(args[i]) ~= "string" then
            return false, string_format("arg[%d] must be string, got %s", i, type(args[i]))
        end
    end
    return true, nil
end

--- Build a shell command from program name and argument array.
--- @param program string
--- @param args table array of string arguments
--- @return string command
function M.build_command(program, args)
    local ok, err = M.validate_program(program)
    if not ok then
        error(err, 2)
    end
    if args and #args > 0 then
        return program .. " " .. M.escape_args(args)
    end
    return program
end

-- Swappable executor (default: os.execute wrapper)
-- pmat:ignore CB-603 — os.execute is the underlying primitive; safety comes from build_command
M._executor = function(cmd)
    return normalize_exit(os.execute(cmd)) -- pmat:ignore CB-603
end

-- Swappable popen (default: io.popen wrapper)
-- pmat:ignore CB-603 — io.popen is the underlying primitive; safety comes from build_command
M._popen = function(cmd)
    local handle = io.popen(cmd, "r") -- pmat:ignore CB-603
    if not handle then
        return false, nil
    end
    local output = handle:read("*a")
    handle:close()
    return true, output
end

--- Execute a command safely via program + args array.
--- @param program string
--- @param args table|nil array of string arguments
--- @return boolean ok, number|nil exit_code
function M.exec(program, args)
    local cmd = M.build_command(program, args or {})
    return M._executor(cmd)
end

--- Capture stdout from a command safely.
--- @param program string
--- @param args table|nil array of string arguments
--- @return boolean ok, string|nil output
function M.capture(program, args)
    local cmd = M.build_command(program, args or {})
    return M._popen(cmd)
end

M._normalize_exit = normalize_exit

return M
