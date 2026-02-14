#!/usr/bin/env lua5.1
--[[
  proxy_tables.lua — Example: __newindex/__index proxy patterns.
  Demonstrates read-only proxies (AwesomeWM gears.matrix), logging
  proxies, validation proxies, computed/virtual properties (lazy.nvim
  semver), and change-detection proxies (Hammerspoon watchable).

  Usage: lua5.1 examples/proxy_tables.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local string_format = string.format
local string_rep = string.rep
local rawset = rawset
local rawget = rawget
local error = error
local pcall = pcall

log.set_level(log.INFO)
log.set_context("proxy-tables")

local function banner(title)
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("Pattern: %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- Pattern 1: Read-only Proxy (AwesomeWM gears.matrix pattern)
--
-- Writes error immediately.  Reads delegate to the original table.
-- A proxy_pairs() helper iterates the underlying data since Lua 5.1
-- __pairs metamethod is not supported.
-- ================================================================

--- Create a read-only proxy over a table.
--- @param t table the table to protect
--- @return table proxy, function proxy_pairs
local function read_only_proxy(t)
    guard.assert_type(t, "table", "t")
    local proxy = setmetatable({}, {
        __index = t,
        __newindex = function(_, key, _value)
            error(string_format("attempt to modify read-only table key: %s", tostring(key)), 2)
        end,
    })

    --- Iterate the underlying table through the proxy.
    --- Lua 5.1 does not honour __pairs, so we provide a helper.
    local function proxy_pairs()
        return pairs(t)
    end

    return proxy, proxy_pairs
end

local function demo_read_only()
    banner("1. Read-only Proxy (AwesomeWM gears.matrix)")

    local config = { host = "api.example.com", port = 443, retries = 3 }
    local frozen, frozen_pairs = read_only_proxy(config)

    -- Reads work
    io.write(string_format("  host:    %s\n", tostring(frozen.host)))
    io.write(string_format("  port:    %s\n", tostring(frozen.port)))
    io.write(string_format("  retries: %s\n", tostring(frozen.retries)))

    -- Iterate via proxy_pairs helper
    io.write("  Iterating via proxy_pairs:\n")
    for k, v in frozen_pairs() do
        io.write(string_format("    %s = %s\n", tostring(k), tostring(v)))
    end

    -- Write blocked
    local ok, err = pcall(function()
        frozen.port = 80
    end)
    io.write(string_format("  Write blocked:  %s\n", tostring(not ok)))
    io.write(string_format("    Error: %s\n", tostring(err)))

    -- Original unchanged
    io.write(string_format("  Original port:  %s\n", tostring(frozen.port)))
end

-- ================================================================
-- Pattern 2: Logging Proxy (debug access-pattern tracer)
--
-- Every read and write is logged with the key (and value for writes).
-- Useful for discovering which fields a piece of code actually uses.
-- ================================================================

--- Create a proxy that logs all reads and writes.
--- @param t table the backing table
--- @param label string a label for log messages
--- @return table proxy
local function logging_proxy(t, label)
    guard.assert_type(t, "table", "t")
    guard.assert_type(label, "string", "label")

    return setmetatable({}, {
        __index = function(_, key)
            local value = t[key]
            log.info("[%s] READ  key=%s value=%s", label, tostring(key), tostring(value))
            return value
        end,
        __newindex = function(_, key, value)
            log.info("[%s] WRITE key=%s value=%s", label, tostring(key), tostring(value))
            rawset(t, key, value)
        end,
    })
end

local function demo_logging_proxy()
    banner("2. Logging Proxy (access tracer)")

    local data = { mode = "fast", count = 0 }
    local traced = logging_proxy(data, "config")

    io.write("  Reading 'mode':\n")
    local mode = traced.mode
    io.write(string_format("    got: %s\n", tostring(mode)))

    io.write("  Writing 'count' = 5:\n")
    traced.count = 5
    io.write(string_format("    backing store: count=%s\n", tostring(data.count)))

    io.write("  Reading unknown key 'missing':\n")
    local missing = traced.missing
    io.write(string_format("    got: %s\n", tostring(missing)))
end

-- ================================================================
-- Pattern 3: Validation Proxy (schema-enforced writes)
--
-- A schema maps field names to expected type strings.  Writes are
-- validated against the schema before being accepted.  Unknown
-- fields are rejected outright.
-- ================================================================

--- Create a proxy that validates writes against a type schema.
--- @param t table the backing table
--- @param schema table mapping field_name -> type_name
--- @return table proxy
local function validation_proxy(t, schema)
    guard.assert_type(t, "table", "t")
    guard.assert_type(schema, "table", "schema")

    return setmetatable({}, {
        __index = t,
        __newindex = function(_, key, value)
            local expected = schema[key]
            if not expected then
                error(string_format("unknown field: %s (not in schema)", tostring(key)), 2)
            end
            guard.assert_type(value, expected, key, 3)
            rawset(t, key, value)
        end,
    })
end

local function demo_validation_proxy()
    banner("3. Validation Proxy (schema-enforced writes)")

    local schema = { name = "string", age = "number", active = "boolean" }
    local record = { name = "Alice", age = 30, active = true }
    local guarded = validation_proxy(record, schema)

    -- Valid reads
    io.write(string_format("  name:   %s\n", tostring(guarded.name)))
    io.write(string_format("  age:    %s\n", tostring(guarded.age)))
    io.write(string_format("  active: %s\n", tostring(guarded.active)))

    -- Valid write
    guarded.age = 31
    io.write(string_format("  Updated age: %s\n", tostring(guarded.age)))

    -- Type mismatch
    local ok1, err1 = pcall(function()
        guarded.age = "not a number"
    end)
    io.write(string_format("  Bad type blocked: %s\n", tostring(not ok1)))
    io.write(string_format("    Error: %s\n", tostring(err1)))

    -- Unknown field
    local ok2, err2 = pcall(function()
        guarded.email = "alice@example.com"
    end)
    io.write(string_format("  Unknown field blocked: %s\n", tostring(not ok2)))
    io.write(string_format("    Error: %s\n", tostring(err2)))
end

-- ================================================================
-- Pattern 4: Computed Properties (lazy.nvim semver virtual fields)
--
-- Some fields are computed from real data.  The proxy checks the
-- computed table first, falls back to the backing table for real
-- fields, and blocks writes to computed fields.
-- ================================================================

--- Create a proxy with virtual computed properties.
--- @param t table the backing table with real fields
--- @param computed table mapping field_name -> function(t)
--- @return table proxy
local function computed_proxy(t, computed)
    guard.assert_type(t, "table", "t")
    guard.assert_type(computed, "table", "computed")

    return setmetatable({}, {
        __index = function(_, key)
            local fn = computed[key]
            if fn then
                return fn(t)
            end
            return t[key]
        end,
        __newindex = function(_, key, value)
            if computed[key] then
                error(string_format("cannot write to computed field: %s", tostring(key)), 2)
            end
            rawset(t, key, value)
        end,
    })
end

local function demo_computed_properties()
    banner("4. Computed Properties (lazy.nvim semver)")

    local person = { first_name = "Grace", last_name = "Hopper", birth_year = 1906 }
    local virtuals = {
        full_name = function(data)
            return data.first_name .. " " .. data.last_name
        end,
        age_approx = function(data)
            return 2026 - data.birth_year
        end,
    }
    local p = computed_proxy(person, virtuals)

    -- Real fields
    io.write(string_format("  first_name: %s\n", tostring(p.first_name)))
    io.write(string_format("  last_name:  %s\n", tostring(p.last_name)))

    -- Computed fields
    io.write(string_format("  full_name:  %s (computed)\n", tostring(p.full_name)))
    io.write(string_format("  age_approx: %s (computed)\n", tostring(p.age_approx)))

    -- Write to real field
    p.first_name = "Rear Admiral Grace"
    io.write(string_format("  Updated first_name: %s\n", tostring(p.first_name)))
    io.write(string_format("  full_name now:      %s\n", tostring(p.full_name)))

    -- Write to computed field blocked
    local ok, err = pcall(function()
        p.full_name = "Override"
    end)
    io.write(string_format("  Computed write blocked: %s\n", tostring(not ok)))
    io.write(string_format("    Error: %s\n", tostring(err)))
end

-- ================================================================
-- Pattern 5: Change Detector (Hammerspoon watchable pattern)
--
-- __newindex compares old and new values.  The on_change callback
-- fires only when the value actually changes, avoiding redundant
-- notifications on idempotent writes.
-- ================================================================

--- Create a proxy that fires on_change only when a value changes.
--- @param t table the backing table
--- @param on_change function(key, old_value, new_value)
--- @return table proxy
local function change_detector(t, on_change)
    guard.assert_type(t, "table", "t")
    guard.assert_type(on_change, "function", "on_change")

    return setmetatable({}, {
        __index = t,
        __newindex = function(_, key, new_value)
            local old_value = rawget(t, key)
            rawset(t, key, new_value)
            if old_value ~= new_value then
                on_change(key, old_value, new_value)
            end
        end,
    })
end

local function demo_change_detection()
    banner("5. Change Detector (Hammerspoon watchable)")

    local state = { volume = 50, muted = false }
    local changes = {}

    local watched = change_detector(state, function(key, old_val, new_val)
        local entry = string_format("%s: %s -> %s", tostring(key), tostring(old_val), tostring(new_val))
        changes[#changes + 1] = entry
        io.write(string_format("    CHANGED %s\n", entry))
    end)

    io.write("  Setting volume = 75 (change):\n")
    watched.volume = 75

    io.write("  Setting volume = 75 (no change, same value):\n")
    watched.volume = 75

    io.write("  Setting muted = true (change):\n")
    watched.muted = true

    io.write("  Setting muted = true (no change, same value):\n")
    watched.muted = true

    io.write("  Setting volume = 0 (change):\n")
    watched.volume = 0

    io.write(string_format("  Total change events fired: %d (expected 3)\n", #changes))

    -- Validate with check_range
    local ok, err = validate.check_range(#changes, 3, 3, "change_count")
    if ok then
        io.write("  Validated: exactly 3 changes detected.\n")
    else
        io.write(string_format("  Validation failed: %s\n", tostring(err)))
    end
end

-- ================================================================
-- Summary
-- ================================================================

local function print_summary()
    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("Proxy Pattern Summary\n")
    io.write(string_rep("=", 60) .. "\n\n")

    local header = string_format("  %-22s  %-14s  %s\n", "Pattern", "Source", "Purpose")
    io.write(header)
    io.write("  " .. string_rep("-", 56) .. "\n")

    local rows = {
        { "Read-only proxy", "AwesomeWM", "Immutable config" },
        { "Logging proxy", "Debug tool", "Access tracing" },
        { "Validation proxy", "Schema guard", "Type-safe writes" },
        { "Computed properties", "lazy.nvim", "Virtual fields" },
        { "Change detector", "Hammerspoon", "Watch for changes" },
    }

    for i = 1, #rows do
        local r = rows[i]
        io.write(string_format("  %-22s  %-14s  %s\n", r[1], r[2], r[3]))
    end

    io.write("  " .. string_rep("-", 56) .. "\n")
    io.write("\n  All patterns use empty proxy + metatable delegation.\n")
    io.write("  Lua 5.1: __pairs not supported; provide helper functions.\n")
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("Proxy Table Patterns (__newindex / __index)\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Five patterns from Hammerspoon, lazy.nvim, and AwesomeWM.\n")

    demo_read_only()
    demo_logging_proxy()
    demo_validation_proxy()
    demo_computed_properties()
    demo_change_detection()
    print_summary()

    io.write("\n")
    log.info("all five proxy table patterns demonstrated")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
