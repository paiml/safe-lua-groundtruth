#!/usr/bin/env lua5.1
--[[
  weak_tables.lua — Example: weak table patterns from top Lua projects.
  Demonstrates weak-value caches (Kong, AwesomeWM), weak-key identity
  tracking (Kong, lazy.nvim), ephemeral associations (APISIX), string
  key anti-patterns, memoization caches, and object metadata.

  Usage: lua5.1 examples/weak_tables.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local log = require("safe.log")

local setmetatable = setmetatable
local collectgarbage = collectgarbage
local string_format = string.format
local string_rep = string.rep
local tostring = tostring
local pairs = pairs

log.set_level(log.INFO)
log.set_context("weak-tables")

--- Count non-nil entries in a table.
--- @param t table
--- @return number
local function count_entries(t)
    guard.assert_type(t, "table", "t")
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

--- Print a section header.
--- @param n number section number
--- @param title string section title
local function section(n, title)
    guard.assert_type(n, "number", "n")
    guard.assert_type(title, "string", "title")
    io.write(string_format("\n%d. %s\n", n, title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ----------------------------------------------------------------
-- 1. Weak values cache (__mode = "v") — Kong, AwesomeWM, KOReader
-- ----------------------------------------------------------------
local function demo_weak_value_cache()
    section(1, 'Weak Values Cache (__mode = "v")')
    io.write("Pattern: cache that allows GC to reclaim unused values.\n")
    io.write("Used by Kong for per-request data, AwesomeWM for widget caches.\n\n")

    local cache = setmetatable({}, { __mode = "v" })

    -- Store table values (tables are reference types; strings/numbers are not)
    local obj_a = { name = "connection-pool" }
    local obj_b = { name = "dns-result" }
    cache["pool"] = obj_a
    cache["dns"] = obj_b

    io.write(string_format("  Before GC: %d entries in cache\n", count_entries(cache)))
    log.debug("cache holds %d entries before GC", count_entries(cache))

    -- Drop reference to obj_b; obj_a stays alive
    local _keep_a = obj_a
    obj_b = nil -- luacheck: ignore 311
    collectgarbage("collect")
    collectgarbage("collect")

    io.write(string_format("  After GC:  %d entries in cache (dns-result collected)\n", count_entries(cache)))
    io.write(string_format('  cache["pool"] = %s (still alive)\n', tostring(cache["pool"] and cache["pool"].name)))
    io.write(string_format('  cache["dns"]  = %s (collected)\n', tostring(cache["dns"])))

    -- Prevent _keep_a from being optimized away
    guard.assert_not_nil(_keep_a, "_keep_a")
end

-- ----------------------------------------------------------------
-- 2. Weak keys for identity tracking (__mode = "k") — Kong, lazy.nvim
-- ----------------------------------------------------------------
local function demo_weak_key_tracking()
    section(2, 'Weak Keys for Identity Tracking (__mode = "k")')
    io.write("Pattern: attach metadata to objects without preventing GC.\n")
    io.write("Used by Kong for request contexts, lazy.nvim for plugin state.\n\n")

    local tracker = setmetatable({}, { __mode = "k" })

    local plugin_a = { id = "rate-limiter" }
    local plugin_b = { id = "auth-jwt" }
    tracker[plugin_a] = { load_time = 0.003, calls = 42 }
    tracker[plugin_b] = { load_time = 0.001, calls = 17 }

    io.write(string_format("  Before GC: tracking %d objects\n", count_entries(tracker)))

    -- Drop reference to plugin_b
    plugin_b = nil -- luacheck: ignore 311
    collectgarbage("collect")
    collectgarbage("collect")

    io.write(string_format("  After GC:  tracking %d objects (auth-jwt collected)\n", count_entries(tracker)))

    -- Verify remaining entry
    local meta = tracker[plugin_a]
    guard.assert_not_nil(meta, "plugin_a metadata")
    io.write(string_format("  rate-limiter metadata: calls=%d\n", meta.calls))
end

-- ----------------------------------------------------------------
-- 3. Ephemeral associations (__mode = "kv") — APISIX
-- ----------------------------------------------------------------
local function demo_ephemeral_associations()
    section(3, 'Ephemeral Associations (__mode = "kv")')
    io.write("Pattern: both keys and values weakly held.\n")
    io.write("Used by APISIX for transient route-to-upstream mappings.\n\n")

    local assoc = setmetatable({}, { __mode = "kv" })

    local route = { path = "/api/v1/users" }
    local upstream = { host = "backend-1.local", port = 8080 }
    assoc[route] = upstream

    io.write(string_format("  Before GC: %d associations\n", count_entries(assoc)))
    io.write(string_format("  route -> upstream: %s:%d\n", upstream.host, upstream.port))

    -- Drop only the upstream reference; since values are also weak, entry may be collected
    local _keep_route = route
    upstream = nil -- luacheck: ignore 311
    collectgarbage("collect")
    collectgarbage("collect")

    local remaining = count_entries(assoc)
    io.write(string_format("  After dropping upstream + GC: %d associations\n", remaining))
    if remaining == 0 then
        io.write("  Entry collected (value was the only weak ref needed)\n")
    else
        io.write("  Entry still present (key keeps it alive in this mode)\n")
    end

    -- Prevent _keep_route from being optimized away
    guard.assert_not_nil(_keep_route, "_keep_route")
end

-- ----------------------------------------------------------------
-- 4. String key misuse (ANTI-PATTERN)
-- ----------------------------------------------------------------
local function demo_string_key_antipattern()
    section(4, "String Key Misuse (ANTI-PATTERN)")
    io.write("Strings are interned in Lua and never garbage-collected.\n")
    io.write("Weak-key tables with string keys NEVER release entries.\n\n")

    local weak_k = setmetatable({}, { __mode = "k" })

    -- Add string keys
    weak_k["session-abc-123"] = { user = "alice" }
    weak_k["session-def-456"] = { user = "bob" }
    weak_k["session-ghi-789"] = { user = "carol" }

    io.write(string_format("  Before GC: %d entries with string keys\n", count_entries(weak_k)))

    -- Force multiple GC cycles
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")

    io.write(string_format("  After GC:  %d entries (strings are NEVER collected)\n", count_entries(weak_k)))
    log.warn("string keys in weak tables are a memory leak anti-pattern")
    io.write("  All 3 entries remain: interned strings have infinite lifetime.\n")
end

-- ----------------------------------------------------------------
-- 5. Memoization cache with weak values
-- ----------------------------------------------------------------
local function demo_memoization_cache()
    section(5, "Memoization Cache with Weak Values")
    io.write("Pattern: cache computed results; allow GC under memory pressure.\n")
    io.write("Results are tables (reference types) so weak refs work.\n\n")

    local memo = setmetatable({}, { __mode = "v" })

    --- Compute a result and wrap it in a table so it can be weakly held.
    --- @param key string
    --- @return table result
    local function expensive_compute(key)
        guard.assert_type(key, "string", "key")
        if memo[key] then
            return memo[key]
        end
        -- Simulate expensive work: result is a table (reference type)
        local result = { value = #key * 42, source = key }
        memo[key] = result
        return result
    end

    -- First call: computes and caches
    local r1 = expensive_compute("alpha")
    local r2 = expensive_compute("beta")
    io.write(string_format("  Computed: alpha=%d, beta=%d\n", r1.value, r2.value))
    io.write(string_format("  Cache entries: %d\n", count_entries(memo)))

    -- Second call: hits cache
    local r1_again = expensive_compute("alpha")
    io.write(string_format("  Cache hit for alpha: %s\n", tostring(r1 == r1_again)))

    -- Drop external refs and force GC
    local _keep_r1 = r1
    r1 = nil -- luacheck: ignore 311
    r1_again = nil -- luacheck: ignore 311
    r2 = nil -- luacheck: ignore 311
    collectgarbage("collect")
    collectgarbage("collect")

    io.write(string_format("  After dropping beta ref + GC: %d cache entries\n", count_entries(memo)))
    io.write(string_format('  memo["alpha"] still alive: %s (external ref kept)\n', tostring(memo["alpha"] ~= nil)))
    io.write(string_format('  memo["beta"] collected: %s\n', tostring(memo["beta"] == nil)))

    -- Prevent _keep_r1 from being optimized away
    guard.assert_not_nil(_keep_r1, "_keep_r1")
end

-- ----------------------------------------------------------------
-- 6. Object metadata without preventing GC
-- ----------------------------------------------------------------
local function demo_object_metadata()
    section(6, "Object Metadata Without Preventing GC")
    io.write("Pattern: attach debug/profiling info to objects via weak-key table.\n")
    io.write("When the object is collected, metadata is automatically cleaned up.\n\n")

    local metadata = setmetatable({}, { __mode = "k" })

    local function register_object(obj, info)
        guard.assert_type(obj, "table", "obj")
        guard.assert_type(info, "table", "info")
        metadata[obj] = info
    end

    local function get_metadata(obj)
        return metadata[obj]
    end

    -- Create objects in a limited scope
    local survivor = { kind = "long-lived-handler" }
    register_object(survivor, { created_at = "2026-02-14T10:00:00", debug_tag = "handler-main" })

    do
        local temp = { kind = "short-lived-request" }
        register_object(temp, { created_at = "2026-02-14T10:00:01", debug_tag = "req-42" })
        io.write(string_format("  Inside scope: %d objects tracked\n", count_entries(metadata)))

        -- temp goes out of scope here
        local _unused = temp -- prevent luacheck warning about unused temp
    end

    collectgarbage("collect")
    collectgarbage("collect")

    io.write(string_format("  After scope exit + GC: %d objects tracked\n", count_entries(metadata)))

    local surv_meta = get_metadata(survivor)
    if surv_meta then
        io.write(string_format("  Survivor metadata: tag=%s\n", surv_meta.debug_tag))
    end
    io.write("  Request metadata: automatically cleaned up by GC.\n")
end

-- ----------------------------------------------------------------
-- Summary
-- ----------------------------------------------------------------
local function print_summary()
    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("Summary of Weak Table Modes\n")
    io.write(string_rep("=", 60) .. "\n\n")
    io.write(string_format("  %-12s %-20s %s\n", "Mode", "Weak Reference", "Use Case"))
    io.write(string_format("  %-12s %-20s %s\n", string_rep("-", 12), string_rep("-", 20), string_rep("-", 24)))
    io.write(string_format("  %-12s %-20s %s\n", '__mode="v"', "Values only", "Caches, memoization"))
    io.write(string_format("  %-12s %-20s %s\n", '__mode="k"', "Keys only", "Identity tracking"))
    io.write(string_format("  %-12s %-20s %s\n", '__mode="kv"', "Keys and values", "Ephemeral mappings"))
    io.write("\n  Caveat: string/number/boolean keys are never collected (interned).\n")
    io.write("  Always use table keys for weak-key tables.\n")
end

-- ----------------------------------------------------------------
-- Main
-- ----------------------------------------------------------------
local function main(_args)
    io.write("Weak Table Patterns from Top Lua Projects\n")
    io.write(string_rep("=", 60) .. "\n")

    demo_weak_value_cache()
    demo_weak_key_tracking()
    demo_ephemeral_associations()
    demo_string_key_antipattern()
    demo_memoization_cache()
    demo_object_metadata()
    print_summary()

    log.info("all weak table demos complete")
    return 0
end

os.exit(main(arg))
