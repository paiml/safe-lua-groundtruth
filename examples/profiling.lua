#!/usr/bin/env lua5.1
--[[
  profiling.lua — Example: performance profiling with safe.perf patterns.
  Compares safe vs unsafe approaches and reports timing, speedup ratios,
  and memory allocation estimates.

  Usage: lua5.1 examples/profiling.lua [iterations]
]]

package.path = "lib/?.lua;" .. package.path

local perf = require("safe.perf")
local log = require("safe.log")
local validate = require("safe.validate")

local os_clock = os.clock
local string_format = string.format
local string_rep = string.rep
local collectgarbage = collectgarbage

log.set_level(log.INFO)
log.set_context("profiler")

local DEFAULT_ITERATIONS = 500

--- Run a function `n` times and return elapsed seconds.
local function time_it(n, fn)
    collectgarbage("collect")
    local start = os_clock()
    for _ = 1, n do
        fn()
    end
    return os_clock() - start
end

--- Format a duration in seconds to a readable string.
local function fmt_time(secs)
    if secs < 0.001 then
        return string_format("%.1f us", secs * 1e6)
    elseif secs < 1 then
        return string_format("%.2f ms", secs * 1000)
    else
        return string_format("%.3f s", secs)
    end
end

--- Print a comparison row.
local function report(label_a, time_a, label_b, time_b)
    local ratio = time_b / time_a
    io.write(string_format("  %-24s %10s\n", label_a, fmt_time(time_a)))
    io.write(string_format("  %-24s %10s\n", label_b, fmt_time(time_b)))
    if ratio > 1 then
        io.write(string_format("  --> %s is %.1fx faster\n\n", label_a, ratio))
    else
        io.write(string_format("  --> %s is %.1fx faster\n\n", label_b, 1 / ratio))
    end
end

local function make_strings(n)
    local t = {}
    for i = 1, n do
        t[i] = "x"
    end
    return t
end

local function make_numbers(n)
    local t = {}
    for i = 1, n do
        t[i] = i
    end
    return t
end

local function main(args)
    local iterations = DEFAULT_ITERATIONS
    if args[1] then
        local ok, _err = validate.check_range(tonumber(args[1]) or 0, 1, 1e6, "iterations")
        if ok then
            iterations = tonumber(args[1])
        else
            log.warn("invalid iterations %q, using default %d", args[1], DEFAULT_ITERATIONS)
        end
    end

    log.info("running %d iterations per benchmark", iterations)
    io.write(string_format("\nPerformance Profile (%d iterations)\n", iterations))
    io.write(string_rep("=", 50) .. "\n\n")

    -- 1. String concatenation: table.concat vs loop
    io.write("String Concatenation (1000 parts)\n")
    io.write(string_rep("-", 50) .. "\n")
    local parts = make_strings(1000)
    local t_safe = time_it(iterations, function()
        perf.concat_safe(parts)
    end)
    local t_unsafe = time_it(iterations, function()
        perf.concat_unsafe(parts)
    end)
    report("table.concat (safe)", t_safe, "loop concat (unsafe)", t_unsafe)

    -- 2. Iteration: numeric for vs ipairs
    io.write("Array Sum (10000 elements)\n")
    io.write(string_rep("-", 50) .. "\n")
    local nums = make_numbers(10000)
    local t_numeric = time_it(iterations, function()
        perf.numeric_for_sum(nums)
    end)
    local t_ipairs = time_it(iterations, function()
        perf.ipairs_sum(nums)
    end)
    report("numeric for", t_numeric, "ipairs", t_ipairs)

    -- 3. Table reuse vs allocation
    io.write("Table Fill (1000 elements)\n")
    io.write(string_rep("-", 50) .. "\n")
    local reuse_buf = {}
    local t_reuse = time_it(iterations, function()
        perf.reuse_table(reuse_buf, 1000)
    end)
    local t_alloc = time_it(iterations, function()
        local _t = {}
        for i = 1, 1000 do
            _t[i] = i
        end
    end)
    report("reuse_table", t_reuse, "new alloc each time", t_alloc)

    -- 4. GC pressure snapshot
    io.write("GC Snapshot\n")
    io.write(string_rep("-", 50) .. "\n")
    collectgarbage("collect")
    local mem_before = collectgarbage("count")
    -- Allocate 10k small tables to show GC impact
    local sink = {}
    for i = 1, 10000 do
        sink[i] = { i, i + 1, i + 2 }
    end
    local mem_after = collectgarbage("count")
    io.write(string_format("  Before allocation:  %.1f KB\n", mem_before))
    io.write(string_format("  After 10k tables:   %.1f KB\n", mem_after))
    io.write(string_format("  Delta:              %.1f KB\n", mem_after - mem_before))
    -- Release references and collect
    for k in pairs(sink) do
        sink[k] = nil
    end
    collectgarbage("collect")
    local mem_freed = collectgarbage("count")
    io.write(string_format("  After GC collect:   %.1f KB\n\n", mem_freed))

    log.info("profiling complete")
    return 0
end

os.exit(main(arg))
