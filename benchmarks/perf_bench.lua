#!/usr/bin/env lua5.1
--[[
  perf_bench.lua — Performance benchmarks for safe.perf patterns.
  Compares safe vs unsafe patterns at various scales.

  Usage: lua5.1 benchmarks/perf_bench.lua
]]

package.path = "lib/?.lua;" .. package.path

local perf = require("safe.perf")

local os_clock = os.clock
local string_format = string.format

local function bench(name, n, fn)
    local start = os_clock()
    local iterations = 1000
    for _ = 1, iterations do
        fn()
    end
    local elapsed = os_clock() - start
    local time_ms = elapsed * 1000
    local ops = iterations / elapsed
    io.write(string_format("%s\t%d\t%.3f\t%.0f\n", name, n, time_ms, ops))
end

local function make_parts(n)
    local parts = {}
    for i = 1, n do
        parts[i] = "x"
    end
    return parts
end

local function make_numbers(n)
    local tbl = {}
    for i = 1, n do
        tbl[i] = i
    end
    return tbl
end

io.write("benchmark\tn\ttime_ms\tops_per_sec\n")
io.write(string.rep("-", 60) .. "\n")

-- String concatenation: safe vs unsafe
for _, n in ipairs({ 100, 1000, 10000 }) do
    local parts = make_parts(n)
    bench("concat_safe", n, function()
        perf.concat_safe(parts)
    end)
    bench("concat_unsafe", n, function()
        perf.concat_unsafe(parts)
    end)
end

-- Iteration: numeric for vs ipairs
for _, n in ipairs({ 10000 }) do
    local tbl = make_numbers(n)
    bench("numeric_for_sum", n, function()
        perf.numeric_for_sum(tbl)
    end)
    bench("ipairs_sum", n, function()
        perf.ipairs_sum(tbl)
    end)
end

-- Table reuse vs new table
for _, n in ipairs({ 1000 }) do
    local reuse_tbl = {}
    bench("reuse_table", n, function()
        perf.reuse_table(reuse_tbl, n)
    end)
    bench("new_table", n, function()
        local t = {}
        for i = 1, n do
            t[i] = i
        end
    end)
end

io.write("\nDone.\n")
