# safe.guard

Defensive programming primitives: nil-safe access, type contracts, frozen tables, and global protection.

```lua
local guard = require("safe.guard")
```

## Source

```lua
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
        error(("expected %s to be %s, got %s"):format(tostring(name), expected, type(value)), (level or 2))
    end
end

--- Nil guard with descriptive error.
--- @param value any
--- @param name string parameter name for error message
--- @param level number|nil stack level for error (default 2)
function M.assert_not_nil(value, name, level)
    if value == nil then
        error(("expected %s to be non-nil"):format(tostring(name)), (level or 2))
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
            error(("attempt to modify frozen table key: %s"):format(tostring(key)), 2)
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
                error(("assignment to undeclared global: %s"):format(tostring(key)), 2)
            end
            rawset(t, key, value)
        end,
        __index = function(_, key)
            if not declared[key] then
                error(("access to undeclared global: %s"):format(tostring(key)), 2)
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
```

## Functions

### `guard.safe_get(tbl, ...)`

Nil-safe chained table access. Traverses nested tables by key without throwing on nil intermediate values.

```lua
local config = { database = { primary = { host = "localhost" } } }

guard.safe_get(config, "database", "primary", "host")  --> "localhost"
guard.safe_get(config, "database", "replica", "host")   --> nil (no error)
guard.safe_get(nil, "anything")                          --> nil
```

Keys can be any type, not just strings — boolean keys work correctly.

### `guard.assert_type(value, expected, name [, level])`

Type contract that throws with a descriptive error if `type(value) ~= expected`.

```lua
guard.assert_type(port, "number", "port")
guard.assert_type(config, "table", "config")
```

The optional `level` parameter controls the stack level in the error message (default: 2, meaning the caller's line).

### `guard.assert_not_nil(value, name [, level])`

Nil guard that throws if `value == nil`.

```lua
guard.assert_not_nil(config, "config")
```

### `guard.freeze(tbl)`

Returns a read-only proxy. Writes to the proxy raise an error.

```lua
local CONSTANTS = guard.freeze({ PI = 3.14159, E = 2.71828 })
print(CONSTANTS.PI)      --> 3.14159
CONSTANTS.PI = 0         --> error: attempt to modify frozen table key: PI
```

### `guard.protect_globals(env)`

Installs a metatable on `env` (default `_G`) that errors on access to or assignment
of undeclared globals. All keys present at call time are considered "declared".

```lua
guard.protect_globals(_G)
x = 42           --> error: assignment to undeclared global: x
print(undefined) --> error: access to undeclared global: undefined
```

### `guard.contract(cond, msg [, level])`

Like `assert()` but with configurable stack level.

```lua
guard.contract(n > 0, "n must be positive")
```

Note: Lua truthiness means `0` and `""` are truthy (unlike C/Python).

### `guard.enum(names)`

Creates a frozen lookup table from an array of string names. Each name maps to itself.

```lua
local COLORS = guard.enum({ "RED", "GREEN", "BLUE" })
print(COLORS.RED)    --> "RED"
COLORS.PURPLE = true --> error: attempt to modify frozen table key: PURPLE
```

## Known Limitations

These are documented behaviors discovered through [falsification testing](../falsification.md):

- **Shallow freeze**: `freeze()` only protects the top-level table. Nested tables
  accessed through the proxy are mutable.
- **No `pairs()` iteration in Lua 5.1**: Frozen proxies are empty tables with `__index`,
  so `pairs()` yields zero entries. Lua 5.1 does not support the `__pairs` metamethod.
- **`rawget` bypass**: `rawget(frozen, key)` returns nil (from the empty proxy), not the underlying value.
- **`protect_globals` replaces metatables**: Any existing metatable on the environment is silently overwritten.
- **Duplicate enum names**: `enum({"A", "B", "A"})` silently deduplicates (last write wins, same value).
