#!/usr/bin/env lua5.1
--[[
  table_operations.lua — Example: table utility patterns from the Lua ecosystem.
  Demonstrates shallow copy, deep clone with cycle detection, crush/merge,
  array join, key/value extraction, search, safe nested access, reverse,
  sparse array compaction, and key counting.

  Source projects: AwesomeWM gears.table (join, crush, clone, keys, reverse,
  find_keys, count_keys, from_sparse), APISIX core.table (try_read_attr,
  array_find, insert_tail).

  Usage: lua5.1 examples/table_operations.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local type = type
local pairs = pairs
local ipairs = ipairs
local select = select
local tostring = tostring
local table_sort = table.sort
local table_concat = table.concat
local string_format = string.format
local string_rep = string.rep
local math_floor = math.floor

log.set_level(log.INFO)
log.set_context("table-ops")

--- Print a section banner.
--- @param n number section number
--- @param title string section title
local function banner(n, title)
    guard.assert_type(n, "number", "n")
    guard.assert_type(title, "string", "title")
    io.write(string_format("\n%d. %s\n", n, title))
    io.write(string_rep("-", 60) .. "\n")
end

--- Format a table as a short string for display.
--- @param t table
--- @return string
local function fmt_table(t)
    if type(t) ~= "table" then
        return tostring(t)
    end
    -- Check if array-like (sequential integer keys starting at 1)
    local is_array = true
    local max_i = 0
    for k in pairs(t) do
        if type(k) == "number" and k == math_floor(k) and k >= 1 then
            if k > max_i then
                max_i = k
            end
        else
            is_array = false
            break
        end
    end
    if is_array and max_i > 0 then
        local parts = {}
        for i = 1, max_i do
            parts[i] = tostring(t[i])
        end
        return "{" .. table_concat(parts, ", ") .. "}"
    end
    -- Hash table: sorted keys
    local ks = {}
    for k in pairs(t) do
        ks[#ks + 1] = k
    end
    table_sort(ks, function(a, b)
        return tostring(a) < tostring(b)
    end)
    local parts = {}
    for i = 1, #ks do
        parts[i] = string_format("%s=%s", tostring(ks[i]), tostring(t[ks[i]]))
    end
    return "{" .. table_concat(parts, ", ") .. "}"
end

-- ----------------------------------------------------------------
-- Table utility functions
-- ----------------------------------------------------------------

--- Shallow copy a table (array or hash).
--- @param t table source table
--- @return table copy
local function shallow_copy(t)
    guard.assert_type(t, "table", "t")
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

--- Deep clone a table with cycle detection.
--- @param t table source table
--- @param seen table|nil cycle detection map (internal)
--- @return table clone
local function deep_clone(t, seen)
    guard.assert_type(t, "table", "t")
    seen = seen or {}
    if seen[t] then
        return seen[t]
    end
    local clone = {}
    seen[t] = clone
    for k, v in pairs(t) do
        if type(v) == "table" then
            clone[k] = deep_clone(v, seen)
        else
            clone[k] = v
        end
    end
    return clone
end

--- Merge source into target, overwriting existing keys (AwesomeWM crush).
--- @param target table destination table (modified in-place)
--- @param source table source table
--- @return table target
local function crush(target, source)
    guard.assert_type(target, "table", "target")
    guard.assert_type(source, "table", "source")
    for k, v in pairs(source) do
        target[k] = v
    end
    return target
end

--- Join multiple arrays into one new array (AwesomeWM join).
--- @param ... table arrays to join
--- @return table joined array
local function join(...)
    local n_args = select("#", ...)
    local result = {}
    for i = 1, n_args do
        local arr = select(i, ...)
        guard.assert_type(arr, "table", string_format("arg[%d]", i))
        for j = 1, #arr do
            result[#result + 1] = arr[j]
        end
    end
    return result
end

--- Return a sorted array of all keys in a table (AwesomeWM keys).
--- @param t table
--- @return table sorted keys
local function keys(t)
    guard.assert_type(t, "table", "t")
    local ks = {}
    for k in pairs(t) do
        ks[#ks + 1] = k
    end
    table_sort(ks, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return ks
end

--- Return an array of all values in a table.
--- @param t table
--- @return table values
local function values(t)
    guard.assert_type(t, "table", "t")
    local vs = {}
    for _, v in pairs(t) do
        vs[#vs + 1] = v
    end
    return vs
end

--- Find the first index of a value in an array (APISIX array_find).
--- @param t table array to search
--- @param value any value to find
--- @return number|nil index or nil if not found
local function array_find(t, value)
    guard.assert_type(t, "table", "t")
    for i = 1, #t do
        if t[i] == value then
            return i
        end
    end
    return nil
end

--- Safely access nested keys (variadic version of guard.safe_get).
--- Returns nil at first missing key instead of erroring.
--- @param t table|nil root table
--- @param ... string|number keys to traverse
--- @return any value or nil
local function safe_nested_get(t, ...)
    local current = t
    for i = 1, select("#", ...) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[select(i, ...)]
    end
    return current
end

--- Reverse an array in-place (AwesomeWM reverse).
--- @param t table array to reverse
--- @return table t (same table, reversed)
local function reverse(t)
    guard.assert_type(t, "table", "t")
    local n = #t
    for i = 1, math_floor(n / 2) do
        t[i], t[n - i + 1] = t[n - i + 1], t[i]
    end
    return t
end

--- Compact a sparse array by removing nil holes (AwesomeWM from_sparse).
--- Uses manual scan to find the maximum integer key.
--- @param t table sparse array
--- @return table compacted array
local function from_sparse(t)
    guard.assert_type(t, "table", "t")
    -- Find max integer key via manual scan
    local max_n = 0
    for k in pairs(t) do
        if type(k) == "number" and k == math_floor(k) and k > max_n then
            max_n = k
        end
    end
    local result = {}
    for i = 1, max_n do
        if t[i] ~= nil then
            result[#result + 1] = t[i]
        end
    end
    return result
end

--- Count all keys in a table (AwesomeWM count_keys).
--- @param t table
--- @return number count
local function count_keys(t)
    guard.assert_type(t, "table", "t")
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

-- ----------------------------------------------------------------
-- Demo functions
-- ----------------------------------------------------------------

local function demo_shallow_vs_deep()
    banner(1, "Shallow Copy vs. Deep Clone")
    io.write("shallow_copy shares nested references; deep_clone does not.\n\n")

    local original = {
        name = "config",
        tags = { "prod", "v2" },
        meta = { author = "alice", nested = { level = 3 } },
    }
    log.info("original: %s", fmt_table(original))

    -- Shallow copy: nested tables are shared
    local shallow = shallow_copy(original)
    shallow.name = "shallow-copy"
    shallow.tags[1] = "MODIFIED"

    io.write(string_format("  original.tags[1] = %s  (shared — also modified!)\n", original.tags[1]))
    io.write(string_format("  shallow.tags[1]  = %s  (modified)\n", shallow.tags[1]))
    io.write(string_format("  same tags table? %s\n", tostring(original.tags == shallow.tags)))

    -- Deep clone: fully independent
    local deep = deep_clone(original)
    deep.tags[1] = "DEEP"
    deep.meta.nested.level = 99

    io.write(string_format("\n  original.tags[1]         = %s  (unchanged by deep clone)\n", original.tags[1]))
    io.write(string_format("  deep.tags[1]             = %s\n", deep.tags[1]))
    io.write(string_format("  original.meta.nested.level = %d  (unchanged)\n", original.meta.nested.level))
    io.write(string_format("  deep.meta.nested.level     = %d\n", deep.meta.nested.level))
    io.write(string_format("  same meta table? %s\n", tostring(original.meta == deep.meta)))

    -- Cycle detection
    io.write("\n  Cycle detection:\n")
    local cyclic = { label = "root" }
    cyclic.self = cyclic
    local cloned = deep_clone(cyclic)
    io.write(string_format("    cyclic.self == cyclic:       %s\n", tostring(cyclic.self == cyclic)))
    io.write(string_format("    cloned.self == cloned:       %s  (cycle preserved)\n", tostring(cloned.self == cloned)))
    io.write(
        string_format("    cloned.self == cyclic:       %s  (independent copy)\n", tostring(cloned.self == cyclic))
    )
    guard.contract(cloned.self == cloned, "cycle must be preserved in clone")
    guard.contract(cloned ~= cyclic, "clone must be independent")
end

local function demo_crush_and_join()
    banner(2, "Crush (Merge) and Join")
    io.write("crush overwrites target keys; join concatenates arrays.\n\n")

    -- Crush: merge configs
    local defaults = { host = "localhost", port = 8080, debug = false, timeout = 30 }
    local overrides = { port = 443, debug = true, tls = true }
    local merged = crush(shallow_copy(defaults), overrides)

    io.write("  defaults:  " .. fmt_table(defaults) .. "\n")
    io.write("  overrides: " .. fmt_table(overrides) .. "\n")
    io.write("  merged:    " .. fmt_table(merged) .. "\n")

    -- Validate merged config
    local c = validate.Checker:new()
    c:check_type(merged.host, "string", "host")
    c:check_type(merged.port, "number", "port")
    c:check_type(merged.debug, "boolean", "debug")
    c:assert()
    log.info("merged config validated: host=%s port=%d", merged.host, merged.port)

    -- Join: concatenate arrays
    local a = { 1, 2, 3 }
    local b = { 4, 5 }
    local c_arr = { 6, 7, 8, 9 }
    local joined = join(a, b, c_arr)

    io.write(string_format("\n  a = %s\n", fmt_table(a)))
    io.write(string_format("  b = %s\n", fmt_table(b)))
    io.write(string_format("  c = %s\n", fmt_table(c_arr)))
    io.write(string_format("  join(a, b, c) = %s\n", fmt_table(joined)))
    guard.contract(#joined == 9, "joined array must have 9 elements")

    -- Join with empty arrays
    local with_empty = join({}, a, {}, b, {})
    io.write(string_format("  join({}, a, {}, b, {}) = %s\n", fmt_table(with_empty)))
    guard.contract(#with_empty == 5, "join with empties must have 5 elements")
end

local function demo_search_and_access()
    banner(3, "Search and Access")
    io.write("keys, values, array_find, safe_nested_get.\n\n")

    local config = { host = "api.example.com", port = 443, timeout = 5000, retries = 3 }

    -- keys: sorted
    local ks = keys(config)
    io.write("  config keys (sorted): " .. fmt_table(ks) .. "\n")

    -- values
    local vs = values(config)
    io.write(string_format("  config values (%d total): %s\n", #vs, fmt_table(vs)))

    -- array_find
    local fruits = { "apple", "banana", "cherry", "date", "elderberry" }
    io.write(string_format("\n  fruits = %s\n", fmt_table(fruits)))
    local idx = array_find(fruits, "cherry")
    io.write(string_format("  array_find(fruits, 'cherry') = %s\n", tostring(idx)))
    local missing = array_find(fruits, "grape")
    io.write(string_format("  array_find(fruits, 'grape')  = %s\n", tostring(missing)))
    guard.contract(idx == 3, "cherry must be at index 3")
    guard.contract(missing == nil, "grape must not be found")

    -- safe_nested_get
    io.write("\n  safe_nested_get:\n")
    local deep = {
        server = {
            database = {
                primary = { host = "db1.internal", port = 5432 },
            },
        },
    }
    local host = safe_nested_get(deep, "server", "database", "primary", "host")
    io.write(string_format("    deep.server.database.primary.host = %s\n", tostring(host)))

    local nope = safe_nested_get(deep, "server", "cache", "redis", "host")
    io.write(string_format("    deep.server.cache.redis.host      = %s  (missing path)\n", tostring(nope)))

    local from_nil = safe_nested_get(nil, "a", "b")
    io.write(string_format("    safe_nested_get(nil, 'a', 'b')    = %s  (nil root)\n", tostring(from_nil)))
    guard.contract(host == "db1.internal", "nested host must resolve")
    guard.contract(nope == nil, "missing path must return nil")
    guard.contract(from_nil == nil, "nil root must return nil")
end

local function demo_array_transforms()
    banner(4, "Array Transforms")
    io.write("reverse, from_sparse, count_keys.\n\n")

    -- reverse
    local nums = { 1, 2, 3, 4, 5 }
    io.write(string_format("  before reverse: %s\n", fmt_table(nums)))
    reverse(nums)
    io.write(string_format("  after reverse:  %s\n", fmt_table(nums)))
    guard.contract(nums[1] == 5, "first element must be 5 after reverse")
    guard.contract(nums[5] == 1, "last element must be 1 after reverse")

    -- reverse with even count
    local even = { "a", "b", "c", "d" }
    reverse(even)
    io.write(string_format("  reverse {a,b,c,d}: %s\n", fmt_table(even)))
    guard.contract(even[1] == "d", "first must be d")
    guard.contract(even[4] == "a", "last must be a")

    -- from_sparse: compact a sparse array
    io.write("\n  from_sparse:\n")
    local sparse = {}
    sparse[1] = "alpha"
    sparse[3] = "charlie"
    sparse[5] = "echo"
    sparse[8] = "hotel"
    io.write("    sparse indices: 1, 3, 5, 8\n")
    io.write(
        string_format(
            "    sparse values:  %s, nil, %s, nil, %s, nil, nil, %s\n",
            tostring(sparse[1]),
            tostring(sparse[3]),
            tostring(sparse[5]),
            tostring(sparse[8])
        )
    )

    local compact = from_sparse(sparse)
    io.write(string_format("    compacted: %s  (%d elements)\n", fmt_table(compact), #compact))
    guard.contract(#compact == 4, "compacted must have 4 elements")
    guard.contract(compact[1] == "alpha", "first must be alpha")
    guard.contract(compact[4] == "hotel", "last must be hotel")

    -- count_keys
    io.write("\n  count_keys:\n")
    local mixed = { x = 1, y = 2, z = 3, [1] = "a", [2] = "b" }
    local cnt = count_keys(mixed)
    io.write(string_format("    table with 3 string keys + 2 integer keys: %d total\n", cnt))
    guard.contract(cnt == 5, "mixed table must have 5 keys")

    local empty = {}
    io.write(string_format("    empty table: %d keys\n", count_keys(empty)))
    guard.contract(count_keys(empty) == 0, "empty table must have 0 keys")
end

-- ----------------------------------------------------------------
-- Validation demo: error handling
-- ----------------------------------------------------------------

local function demo_error_handling()
    banner(5, "Error Handling")
    io.write("guard.assert_type catches invalid inputs to table utilities.\n\n")

    -- Passing non-table to shallow_copy
    local ok, err = pcall(shallow_copy, "not a table")
    io.write(string_format("  shallow_copy('not a table'): ok=%s\n", tostring(ok)))
    io.write(string_format("    error: %s\n", tostring(err)))

    -- Passing non-table to join
    ok, err = pcall(join, { 1, 2 }, 42)
    io.write(string_format("  join({1,2}, 42):             ok=%s\n", tostring(ok)))
    io.write(string_format("    error: %s\n", tostring(err)))

    -- Passing non-table to keys
    ok, err = pcall(keys, nil)
    io.write(string_format("  keys(nil):                   ok=%s\n", tostring(ok)))
    io.write(string_format("    error: %s\n", tostring(err)))

    -- Validate.Checker on utility results
    local config = { host = "localhost", port = 8080 }
    local merged = crush(shallow_copy(config), { port = 443, tls = true })
    local checker = validate.Checker:new()
    checker:check_type(merged.host, "string", "host")
    checker:check_type(merged.port, "number", "port")
    checker:check_type(merged.tls, "boolean", "tls")
    io.write(
        string_format("\n  Checker on merged config: ok=%s, errors=%d\n", tostring(checker:ok()), #checker:errors())
    )
end

-- ----------------------------------------------------------------
-- Summary
-- ----------------------------------------------------------------

local function print_summary()
    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("Table Utility Function Reference\n")
    io.write(string_rep("=", 60) .. "\n\n")
    local rows = {
        { "shallow_copy(t)", "Shallow copy (shared refs)", "AwesomeWM" },
        { "deep_clone(t)", "Deep copy + cycle detection", "AwesomeWM" },
        { "crush(target, src)", "Merge src into target", "AwesomeWM" },
        { "join(...)", "Concatenate arrays", "AwesomeWM" },
        { "keys(t)", "Sorted key array", "AwesomeWM" },
        { "values(t)", "Value array", "AwesomeWM" },
        { "array_find(t, v)", "First index of value", "APISIX" },
        { "safe_nested_get(t,...)", "Nil-safe nested access", "APISIX" },
        { "reverse(t)", "Reverse array in-place", "AwesomeWM" },
        { "from_sparse(t)", "Compact sparse array", "AwesomeWM" },
        { "count_keys(t)", "Count all keys", "AwesomeWM" },
    }
    io.write(string_format("  %-24s %-30s %s\n", "Function", "Description", "Origin"))
    io.write(string_format("  %-24s %-30s %s\n", string_rep("-", 24), string_rep("-", 30), string_rep("-", 10)))
    for _, row in ipairs(rows) do
        io.write(string_format("  %-24s %-30s %s\n", row[1], row[2], row[3]))
    end
end

-- ----------------------------------------------------------------
-- Main
-- ----------------------------------------------------------------

local function main(_args)
    io.write("Table Operations — Utility Patterns from the Lua Ecosystem\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Patterns from AwesomeWM gears.table and APISIX core.table.\n")

    demo_shallow_vs_deep()
    demo_crush_and_join()
    demo_search_and_access()
    demo_array_transforms()
    demo_error_handling()
    print_summary()

    io.write("\n")
    log.info("all table operation demos complete")
    return 0
end

os.exit(main(arg))
