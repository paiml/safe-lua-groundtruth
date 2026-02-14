#!/usr/bin/env lua5.1
--[[
  vararg_patterns.lua — Example: variadic function idioms from real Lua projects.
  Demonstrates nil-safe pack/unpack, safe vararg iteration, insert_tail,
  array joining, argument overloading, and safe vararg forwarding.

  Source projects: AwesomeWM gears.table.join (select("#",...)),
  APISIX core.table (insert_tail with select), lite-xl doc, xmake.

  Usage: lua5.1 examples/vararg_patterns.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local type = type
local pairs = pairs
local tostring = tostring
local string_format = string.format
local string_rep = string.rep
local select = select
local unpack = unpack
local ipairs = ipairs
local table_concat = table.concat
local pcall = pcall

log.set_level(log.INFO)
log.set_context("vararg")

--- Print a section banner.
--- @param title string section title
local function banner(title)
    guard.assert_type(title, "string", "title")
    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("  " .. title .. "\n")
    io.write(string_rep("=", 60) .. "\n\n")
end

--- Print a sub-section header.
--- @param title string sub-section title
local function section(title)
    io.write("--- " .. title .. " ---\n")
end

-- ============================================================
-- Pattern 1: safe_pack — nil-safe pack for Lua 5.1
-- Lua 5.1 has no table.pack. The naive `{...}` loses trailing
-- nils because # stops at the first nil hole. select("#", ...)
-- correctly counts ALL arguments including trailing nils.
-- Source: AwesomeWM, APISIX, xmake — all use select("#", ...).
-- ============================================================

--- Nil-safe variadic pack for Lua 5.1.
--- Returns a table with an explicit `n` field for the true arg count.
--- @param ... any arguments to pack
--- @return table packed table with n field
local function safe_pack(...)
    -- selene: allow(mixed_table)
    return { n = select("#", ...), ... }
end

-- ============================================================
-- Pattern 2: safe_unpack — unpack from a packed table
-- Without the explicit third argument, unpack stops at the
-- first nil hole in Lua 5.1. By passing packed.n we guarantee
-- all positions (including nil ones) are returned.
-- ============================================================

--- Unpack a table produced by safe_pack, preserving nil holes.
--- @param packed table a table with an n field
--- @return ... the unpacked values
local function safe_unpack(packed)
    guard.assert_type(packed, "table", "packed")
    guard.assert_not_nil(packed.n, "packed.n")
    return unpack(packed, 1, packed.n)
end

-- ============================================================
-- Pattern 3: vararg_iterate — safe iteration over varargs
-- ipairs({...}) stops at the first nil. Using select in a
-- counted loop correctly visits every position.
-- ============================================================

--- Iterate over all vararg positions, including nil holes.
--- Calls fn(index, value) for each position.
--- @param fn function callback receiving (index, value)
--- @param ... any variadic arguments
local function vararg_iterate(fn, ...)
    guard.assert_type(fn, "function", "fn")
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        fn(i, v)
    end
end

-- ============================================================
-- Pattern 4: insert_tail — append multiple values (APISIX)
-- APISIX core.table.insert_tail appends all varargs to an
-- existing array using select to iterate the varargs.
-- ============================================================

--- Append multiple values to the end of an array.
--- @param t table target array
--- @param ... any values to append
local function insert_tail(t, ...)
    guard.assert_type(t, "table", "t")
    for i = 1, select("#", ...) do
        t[#t + 1] = select(i, ...)
    end
end

-- ============================================================
-- Pattern 5: join_arrays — join N arrays (AwesomeWM)
-- AwesomeWM gears.table.join concatenates an arbitrary number
-- of arrays passed as varargs into a single new array.
-- ============================================================

--- Join multiple arrays into a single new array.
--- @param ... table arrays to join
--- @return table joined result
local function join_arrays(...)
    local result = {}
    for i = 1, select("#", ...) do
        local arr = select(i, ...)
        guard.assert_type(arr, "table", string_format("arg[%d]", i))
        for _, v in ipairs(arr) do
            result[#result + 1] = v
        end
    end
    return result
end

-- ============================================================
-- Pattern 6: overloaded_function — argument overloading
-- A common Lua idiom: dispatch based on type and count of
-- arguments. Used in lite-xl, xmake, and many plugin APIs.
-- ============================================================

--- Overloaded function that accepts multiple call signatures:
---   (string)          — look up by name
---   (string, number)  — look up by name with limit
---   (table)           — batch look up from a config table
--- @param ... any arguments
--- @return string description of what was dispatched
local function overloaded_function(...)
    local argc = select("#", ...)
    local first = select(1, ...)

    if argc == 1 and type(first) == "string" then
        log.debug("dispatch: single string '%s'", first)
        return string_format("lookup(%s)", first)
    elseif argc == 2 and type(first) == "string" then
        local second = select(2, ...)
        local c = validate.Checker:new()
        c:check_type(second, "number", "limit")
        c:assert()
        log.debug("dispatch: string '%s' with limit %d", first, second)
        return string_format("lookup(%s, limit=%d)", first, second)
    elseif argc == 1 and type(first) == "table" then
        local keys = {}
        for k in pairs(first) do
            keys[#keys + 1] = tostring(k)
        end
        log.debug("dispatch: table with %d keys", #keys)
        return string_format("batch_lookup({%s})", table_concat(keys, ", "))
    else
        guard.contract(false, string_format("unsupported call: argc=%d, type=%s", argc, type(first)))
    end
end

-- ============================================================
-- Pattern 7: forward_varargs — safe forwarding
-- Direct fn(...) can lose trailing nils in certain contexts.
-- Packing with n then unpacking with explicit n guarantees
-- all arguments (including trailing nils) reach the target.
-- ============================================================

--- Forward variadic arguments to a function, preserving trailing nils.
--- @param fn function target function
--- @param ... any arguments to forward
--- @return ... whatever fn returns
local function forward_varargs(fn, ...)
    guard.assert_type(fn, "function", "fn")
    local packed = safe_pack(...)
    return fn(safe_unpack(packed))
end

-- ============================================================
-- Demo functions
-- ============================================================

local function demo_pack_unpack()
    banner("Pattern 1-2: safe_pack / safe_unpack")

    section("Trailing nil preservation")
    io.write("  Lua 5.1 gotcha: {1, nil, 3, nil} has # == 1 or 3 (undefined)\n")
    io.write("  select('#', 1, nil, 3, nil) always returns 4\n\n")

    -- Naive pack loses trailing nils
    local naive = { 1, nil, "three", nil }
    io.write(string_format("  naive {1,nil,'three',nil}:  # = %d\n", #naive))

    -- safe_pack preserves them
    local packed = safe_pack(1, nil, "three", nil)
    io.write(string_format("  safe_pack(1,nil,'three',nil): n = %d\n", packed.n))
    guard.contract(packed.n == 4, "safe_pack must count all args")

    -- safe_unpack recovers all positions
    section("Round-trip via safe_unpack")
    local a, b, c, d = safe_unpack(packed)
    io.write(string_format("  a=%s  b=%s  c=%s  d=%s\n", tostring(a), tostring(b), tostring(c), tostring(d)))
    guard.contract(a == 1, "first arg must be 1")
    guard.contract(b == nil, "second arg must be nil")
    guard.contract(c == "three", "third arg must be 'three'")
    guard.contract(d == nil, "fourth arg must be nil")

    -- Edge case: zero arguments
    local empty = safe_pack()
    io.write(string_format("\n  safe_pack():  n = %d\n", empty.n))
    guard.contract(empty.n == 0, "empty pack must have n=0")

    -- Edge case: single nil
    local single_nil = safe_pack(nil)
    io.write(string_format("  safe_pack(nil): n = %d\n", single_nil.n))
    guard.contract(single_nil.n == 1, "single nil pack must have n=1")
    log.info("pack/unpack round-trip verified")
    io.write("\n")
end

local function demo_vararg_iteration()
    banner("Pattern 3: vararg_iterate")

    section("ipairs vs select loop with nil holes")
    local test_args = safe_pack("a", nil, "c", nil, "e")

    -- ipairs stops at first nil
    io.write("  ipairs({...}) visits:\n")
    local ipairs_count = 0
    for i, v in ipairs({ "a", nil, "c", nil, "e" }) do
        ipairs_count = ipairs_count + 1
        io.write(string_format("    [%d] = %s\n", i, tostring(v)))
    end
    io.write(string_format("  ipairs saw %d elements (stops at first nil)\n\n", ipairs_count))

    -- vararg_iterate visits all positions
    io.write("  vararg_iterate visits:\n")
    local select_count = 0
    vararg_iterate(function(i, v)
        select_count = select_count + 1
        io.write(string_format("    [%d] = %s\n", i, tostring(v)))
    end, safe_unpack(test_args))
    io.write(string_format("  select loop saw %d elements (all positions)\n", select_count))

    guard.contract(ipairs_count == 1, "ipairs must stop at first nil")
    guard.contract(select_count == 5, "select loop must visit all 5 positions")
    log.info("vararg iteration comparison complete")
    io.write("\n")
end

local function demo_insert_and_join()
    banner("Pattern 4-5: insert_tail and join_arrays")

    section("insert_tail (APISIX pattern)")
    local t = { "existing" }
    insert_tail(t, "alpha", "beta", "gamma")
    io.write(string_format("  after insert_tail: {%s}\n", table_concat(t, ", ")))
    guard.contract(#t == 4, "table must have 4 elements after insert_tail")
    guard.contract(t[1] == "existing", "first element unchanged")
    guard.contract(t[4] == "gamma", "last inserted element is gamma")

    -- insert_tail with nil args (they become part of the array)
    local t2 = {}
    insert_tail(t2, 1, nil, 3)
    io.write(string_format("  insert_tail({}, 1, nil, 3): #t2 = %d\n", #t2))
    io.write(string_format("    t2[1]=%s  t2[2]=%s  t2[3]=%s\n", tostring(t2[1]), tostring(t2[2]), tostring(t2[3])))

    io.write("\n")
    section("join_arrays (AwesomeWM pattern)")
    local a = { 1, 2, 3 }
    local b = { 4, 5 }
    local c = { 6, 7, 8 }
    local joined = join_arrays(a, b, c)
    local parts = {}
    for i = 1, #joined do
        parts[i] = tostring(joined[i])
    end
    io.write(string_format("  join_arrays({1,2,3}, {4,5}, {6,7,8}) = {%s}\n", table_concat(parts, ", ")))
    guard.contract(#joined == 8, "joined array must have 8 elements")
    guard.contract(joined[1] == 1, "first element is 1")
    guard.contract(joined[8] == 8, "last element is 8")

    -- join with empty arrays
    local with_empty = join_arrays({}, a, {}, b, {})
    io.write(string_format("  join_arrays({}, {1,2,3}, {}, {4,5}, {}) = %d elements\n", #with_empty))
    guard.contract(#with_empty == 5, "join with empties must have 5 elements")

    log.info("insert_tail and join_arrays verified")
    io.write("\n")
end

local function demo_overloading()
    banner("Pattern 6: Argument Overloading")

    section("Dispatch by type and count")

    -- Single string
    local r1 = overloaded_function("users")
    io.write(string_format("  overloaded('users')         = %s\n", r1))

    -- String + number
    local r2 = overloaded_function("users", 10)
    io.write(string_format("  overloaded('users', 10)     = %s\n", r2))

    -- Table
    local r3 = overloaded_function({ name = "alice", role = "admin" })
    io.write(string_format("  overloaded({name, role})    = %s\n", r3))

    -- Invalid call (caught by guard.contract)
    local ok, err = pcall(overloaded_function, 42)
    io.write(string_format("\n  overloaded(42):  ok=%s\n", tostring(ok)))
    io.write(string_format("    error: %s\n", tostring(err)))
    guard.contract(not ok, "invalid overload must error")

    -- Invalid second arg type (caught by validate.Checker)
    ok, err = pcall(overloaded_function, "users", "not-a-number")
    io.write(string_format("  overloaded('users', 'not-a-number'): ok=%s\n", tostring(ok)))
    io.write(string_format("    error: %s\n", tostring(err)))
    guard.contract(not ok, "wrong type for limit must error")

    log.info("overloading dispatch verified")
    io.write("\n")
end

local function demo_forwarding()
    banner("Pattern 7: Safe Vararg Forwarding")

    section("Forwarding preserves trailing nils")

    --- Test target that expects exactly 3 args (some may be nil).
    --- Returns a description of what it received.
    local function target(a, b, c)
        return string_format("a=%s b=%s c=%s (argc via method=%d)", tostring(a), tostring(b), tostring(c), 3)
    end

    -- Direct call — works fine
    local direct = target("x", nil, "z")
    io.write(string_format("  direct call:    %s\n", direct))

    -- Forwarded call — also preserves nils
    local forwarded = forward_varargs(target, "x", nil, "z")
    io.write(string_format("  forwarded call: %s\n", forwarded))

    section("Forwarding with all-nil arguments")
    local all_nil = forward_varargs(target, nil, nil, nil)
    io.write(string_format("  all-nil forwarded: %s\n", all_nil))

    -- Verify the forwarding is equivalent
    section("Round-trip count verification")
    local function count_args(...)
        return select("#", ...)
    end

    local n1 = forward_varargs(count_args, 1, nil, 3, nil)
    io.write(string_format("  forward_varargs(count_args, 1, nil, 3, nil) = %d\n", n1))
    guard.contract(n1 == 4, "forwarded arg count must be 4")

    local n2 = forward_varargs(count_args)
    io.write(string_format("  forward_varargs(count_args) = %d\n", n2))
    guard.contract(n2 == 0, "forwarded zero args must give 0")

    local n3 = forward_varargs(count_args, nil)
    io.write(string_format("  forward_varargs(count_args, nil) = %d\n", n3))
    guard.contract(n3 == 1, "forwarded single nil must give 1")

    log.info("vararg forwarding verified")
    io.write("\n")
end

-- ============================================================
-- Summary
-- ============================================================

local function print_summary()
    io.write(string_rep("=", 60) .. "\n")
    io.write("Vararg Pattern Reference\n")
    io.write(string_rep("=", 60) .. "\n\n")
    local rows = {
        { "safe_pack(...)", "Nil-safe pack with n field", "AwesomeWM, xmake" },
        { "safe_unpack(t)", "Unpack with explicit n", "AwesomeWM, xmake" },
        { "vararg_iterate(fn,...)", "Iterate all positions", "lite-xl" },
        { "insert_tail(t,...)", "Append multiple values", "APISIX" },
        { "join_arrays(...)", "Join N arrays into one", "AwesomeWM" },
        { "overloaded_function", "Type/count dispatch", "lite-xl, xmake" },
        { "forward_varargs(fn,...)", "Safe nil-preserving forward", "General" },
    }
    io.write(string_format("  %-24s %-28s %s\n", "Function", "Description", "Origin"))
    io.write(string_format("  %-24s %-28s %s\n", string_rep("-", 24), string_rep("-", 28), string_rep("-", 16)))
    for _, row in ipairs(rows) do
        io.write(string_format("  %-24s %-28s %s\n", row[1], row[2], row[3]))
    end
end

-- ============================================================
-- Main
-- ============================================================

local function main(_args)
    io.write("Variadic Function Idioms in Lua 5.1\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Patterns from AwesomeWM, APISIX, lite-xl, and xmake.\n")

    demo_pack_unpack()
    demo_vararg_iteration()
    demo_insert_and_join()
    demo_overloading()
    demo_forwarding()
    print_summary()

    io.write("\n")
    log.info("all vararg pattern demos complete")
    return 0
end

os.exit(main(arg))
