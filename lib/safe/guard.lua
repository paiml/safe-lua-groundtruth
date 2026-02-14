--[[
  guard.lua — Defensive programming primitives.
  Nil-safe access, type contracts, frozen tables, global protection.
]]

local M = {}

local type = type
local error = error
local setmetatable = setmetatable
local rawset = rawset
local pairs = pairs
local tostring = tostring
local string_format = string.format

--- Nil-safe chained table access. Returns nil at first miss.
--- @param tbl table|nil
--- @param ... string keys to traverse
--- @return any
function M.safe_get(tbl, ...)
    local current = tbl
    for i = 1, select("#", ...) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[select(i, ...)]
    end
    return current
end

--- Type contract with stack-level error.
--- @param value any
--- @param expected string expected type name
--- @param name string parameter name for error message
--- @param level number|nil stack level for error (default 2)
function M.assert_type(value, expected, name, level)
    if type(value) ~= expected then
        local msg = string_format("expected %s to be %s, got %s", tostring(name), expected, type(value))
        error(msg, (level or 2))
    end
end

--- Nil guard with descriptive error.
--- @param value any
--- @param name string parameter name for error message
--- @param level number|nil stack level for error (default 2)
function M.assert_not_nil(value, name, level)
    if value == nil then
        error(string_format("expected %s to be non-nil", tostring(name)), (level or 2))
    end
end

--- Read-only proxy via metatable.
--- @param tbl table
--- @return table frozen proxy
function M.freeze(tbl)
    local proxy = {}
    setmetatable(proxy, {
        __index = tbl,
        __newindex = function(_, key, _value)
            error(string_format("attempt to modify frozen table key: %s", tostring(key)), 2)
        end,
    })
    return proxy
end

--- Metatable on env that errors on undeclared global access.
--- @param env table environment to protect (default: _G)
--- @return table the protected environment
function M.protect_globals(env)
    -- selene: allow(global_usage)
    env = env or _G -- pmat:ignore CB-603
    local declared = {}
    for k, _ in pairs(env) do
        declared[k] = true
    end
    setmetatable(env, {
        __newindex = function(t, key, value)
            if not declared[key] then
                error(string_format("assignment to undeclared global: %s", tostring(key)), 2)
            end
            rawset(t, key, value)
        end,
        __index = function(_, key)
            if not declared[key] then
                error(string_format("access to undeclared global: %s", tostring(key)), 2)
            end
            return nil
        end,
    })
    return env
end

--- Like assert() with configurable stack level.
--- @param cond any condition to check
--- @param msg string error message
--- @param level number|nil stack level for error (default 2)
function M.contract(cond, msg, level)
    if not cond then
        error(msg, (level or 2))
    end
end

--- Create a frozen lookup table from a list of string names.
--- @param names table array of string names
--- @return table frozen enum table
function M.enum(names)
    local tbl = {}
    for i = 1, #names do
        tbl[names[i]] = names[i]
    end
    return M.freeze(tbl)
end

return M
