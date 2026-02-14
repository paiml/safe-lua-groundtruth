#!/usr/bin/env lua5.1
--[[
  string_building.lua — Example: string building patterns and anti-patterns.
  Demonstrates the O(n^2) accumulator bug, table.concat as the universal fix,
  string.format for structured output, perf.concat_safe vs perf.concat_unsafe,
  benchmark comparison, real-world serialization, and false-positive detection.
  Patterns from Kong, APISIX, KOReader, and CB-605 analysis.

  Usage: lua5.1 examples/string_building.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local log = require("safe.log")
local perf = require("safe.perf")

local os_clock = os.clock
local string_format = string.format
local string_rep = string.rep
local table_concat = table.concat
local collectgarbage = collectgarbage
local tostring = tostring
local pairs = pairs
local ipairs = ipairs

log.set_level(log.INFO)
log.set_context("strings")

-- ----------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------

--- Run a function n times and return elapsed seconds.
--- @param n number repetitions
--- @param fn function to benchmark
--- @return number elapsed seconds
local function time_it(n, fn)
    collectgarbage("collect")
    local start = os_clock()
    for _ = 1, n do
        fn()
    end
    return os_clock() - start
end

--- Format seconds to a human-readable string.
--- @param secs number
--- @return string
local function fmt_time(secs)
    if secs < 0.001 then
        return string_format("%.1f us", secs * 1e6)
    elseif secs < 1 then
        return string_format("%.2f ms", secs * 1000)
    else
        return string_format("%.3f s", secs)
    end
end

--- Build test data: array of N short strings.
--- @param n number
--- @return table
local function make_items(n)
    guard.assert_type(n, "number", "n")
    local items = {}
    for i = 1, n do
        items[i] = string_format("item_%04d", i)
    end
    return items
end

-- ----------------------------------------------------------------
-- Pattern 1: Accumulator Anti-Pattern (O(n^2) -- CB-605)
-- ----------------------------------------------------------------

--- BAD: Quadratic string building via repeated concatenation.
--- Each iteration allocates a new string copying all previous content.
--- @param items table array of strings
--- @return string
local function build_accumulator(items)
    guard.assert_type(items, "table", "items")
    local result = ""
    for i = 1, #items do
        result = result .. items[i] -- O(n^2) total allocations
    end
    return result
end

-- ----------------------------------------------------------------
-- Pattern 2: table.concat (universal correct pattern)
-- ----------------------------------------------------------------

--- GOOD: Linear string building via table.concat.
--- Collect parts into an array, join once at the end.
--- @param items table array of strings
--- @return string
local function build_table_concat(items)
    guard.assert_type(items, "table", "items")
    local parts = {}
    for i = 1, #items do
        parts[#parts + 1] = items[i]
    end
    return table_concat(parts)
end

--- GOOD: table.concat with separator (comma-separated list).
--- @param items table array of strings
--- @param sep string separator
--- @return string
local function build_with_separator(items, sep)
    guard.assert_type(items, "table", "items")
    guard.assert_type(sep, "string", "sep")
    local parts = {}
    for i = 1, #items do
        parts[#parts + 1] = items[i]
    end
    return table_concat(parts, sep)
end

-- ----------------------------------------------------------------
-- Pattern 3: string.format for structured output (Kong/APISIX)
-- ----------------------------------------------------------------

--- Build formatted log lines using cached string.format.
--- @param entries table array of {name, line, msg}
--- @return string
local function build_formatted(entries)
    guard.assert_type(entries, "table", "entries")
    local fmt = string_format
    local parts = {}
    for i = 1, #entries do
        local e = entries[i]
        parts[#parts + 1] = fmt("error in %s at line %d: %s", e.name, e.line, e.msg)
    end
    return table_concat(parts, "\n")
end

-- ----------------------------------------------------------------
-- Pattern 6: Real-world serialization (KOReader dump pattern)
-- ----------------------------------------------------------------

--- Serialize a flat table to a JSON-style string using insert-then-concat.
--- @param data table flat key-value table
--- @return string
local function serialize_table(data)
    guard.assert_type(data, "table", "data")
    local out = {}
    out[#out + 1] = "{"
    for k, v in pairs(data) do
        out[#out + 1] = string_format("  %q: %q,", tostring(k), tostring(v))
    end
    out[#out + 1] = "}"
    return table_concat(out, "\n")
end

-- ----------------------------------------------------------------
-- Main
-- ----------------------------------------------------------------

local function main(_args)
    io.write("String Building Patterns\n")
    io.write(string_rep("=", 60) .. "\n\n")

    -- ============================================================
    -- 1. Accumulator Anti-Pattern
    -- ============================================================
    io.write("1. Accumulator Anti-Pattern (O(n^2) -- CB-605)\n")
    io.write(string_rep("-", 60) .. "\n")
    io.write("  BAD:  result = result .. items[i]  -- each iteration\n")
    io.write("        copies the entire string so far, leading to\n")
    io.write("        O(n^2) total allocations.\n")
    local small = make_items(5)
    local acc_result = build_accumulator(small)
    io.write(string_format("  Demo (5 items): %q\n\n", acc_result))

    -- ============================================================
    -- 2. table.concat (correct pattern)
    -- ============================================================
    io.write("2. table.concat (O(n) -- universal fix)\n")
    io.write(string_rep("-", 60) .. "\n")
    io.write("  GOOD: Collect parts in a table, join once.\n")
    local tc_result = build_table_concat(small)
    io.write(string_format("  Plain:     %q\n", tc_result))
    local sep_result = build_with_separator(small, ", ")
    io.write(string_format("  Separator: %q\n\n", sep_result))

    -- ============================================================
    -- 3. string.format for formatted output
    -- ============================================================
    io.write("3. string.format (Kong/APISIX pattern)\n")
    io.write(string_rep("-", 60) .. "\n")
    io.write("  Cache as: local fmt = string.format\n")
    local entries = {
        { name = "router", line = 42, msg = "no upstream" },
        { name = "auth", line = 87, msg = "token expired" },
        { name = "proxy", line = 15, msg = "timeout" },
    }
    local formatted = build_formatted(entries)
    io.write(formatted .. "\n\n")

    -- ============================================================
    -- 4. perf.concat_safe vs perf.concat_unsafe
    -- ============================================================
    io.write("4. perf.concat_safe vs perf.concat_unsafe\n")
    io.write(string_rep("-", 60) .. "\n")
    local demo_parts = make_items(10)
    local safe_result = perf.concat_safe(demo_parts)
    local unsafe_result = perf.concat_unsafe(demo_parts)
    io.write(string_format("  safe   len: %d\n", #safe_result))
    io.write(string_format("  unsafe len: %d\n", #unsafe_result))
    guard.contract(safe_result == unsafe_result, "safe and unsafe must produce identical output")
    io.write("  Results match: true\n\n")

    -- ============================================================
    -- 5. Benchmark comparison
    -- ============================================================
    io.write("5. Benchmark Comparison\n")
    io.write(string_rep("-", 60) .. "\n")

    local sizes = { 1000, 10000 }
    local header = string_format("  %-28s %10s %10s %10s\n", "Method", "N", "Time", "Length")
    io.write(header)
    io.write("  " .. string_rep("-", 58) .. "\n")

    for _, n in ipairs(sizes) do
        local items = make_items(n)
        local iterations = (n <= 1000) and 100 or 10

        -- Accumulator (unsafe)
        local t_acc = time_it(iterations, function()
            build_accumulator(items)
        end)
        local acc_len = #build_accumulator(items)
        io.write(string_format("  %-28s %10d %10s %10d\n", "accumulator (O(n^2))", n, fmt_time(t_acc), acc_len))

        -- table.concat
        local t_tc = time_it(iterations, function()
            build_table_concat(items)
        end)
        local tc_len = #build_table_concat(items)
        io.write(string_format("  %-28s %10d %10s %10d\n", "table.concat (O(n))", n, fmt_time(t_tc), tc_len))

        -- perf.concat_safe
        local t_safe = time_it(iterations, function()
            perf.concat_safe(items)
        end)
        local safe_len = #perf.concat_safe(items)
        io.write(string_format("  %-28s %10d %10s %10d\n", "perf.concat_safe", n, fmt_time(t_safe), safe_len))

        -- perf.concat_unsafe
        local t_unsf = time_it(iterations, function()
            perf.concat_unsafe(items)
        end)
        local unsf_len = #perf.concat_unsafe(items)
        io.write(string_format("  %-28s %10d %10s %10d\n", "perf.concat_unsafe", n, fmt_time(t_unsf), unsf_len))

        -- Verify correctness
        guard.contract(acc_len == tc_len, "lengths must match")
        guard.contract(tc_len == safe_len, "lengths must match")
        guard.contract(safe_len == unsf_len, "lengths must match")

        if n < sizes[#sizes] then
            io.write("\n")
        end
    end
    io.write("\n")

    -- ============================================================
    -- 6. Real-world serialization (KOReader dump pattern)
    -- ============================================================
    io.write("6. Serialization Pattern (KOReader dump)\n")
    io.write(string_rep("-", 60) .. "\n")
    io.write("  Insert parts into table, join with table.concat:\n\n")
    local data = { host = "127.0.0.1", port = "8080", proto = "https" }
    local serialized = serialize_table(data)
    io.write(serialized .. "\n\n")

    -- ============================================================
    -- 7. Single concat per iteration (false positive)
    -- ============================================================
    io.write("7. Single Concat Per Iteration (NOT a problem)\n")
    io.write(string_rep("-", 60) .. "\n")
    io.write("  A single '..' per loop body is O(n), not O(n^2).\n")
    io.write("  Each iteration produces an independent string;\n")
    io.write("  no accumulator grows across iterations.\n\n")

    local names = { "alpha", "bravo", "charlie" }
    for _, name in ipairs(names) do
        -- Single concat per iteration: fine, not accumulating
        log.debug("Processing: " .. name)
        io.write("  Processing: " .. name .. "\n")
    end

    io.write("\n" .. string_rep("=", 60) .. "\n")
    log.info("string building demo complete")
    return 0
end

os.exit(main(arg))
