#!/usr/bin/env lua5.1
--[[
  mutate.lua — Example: mutation testing harness.
  Takes a pure function, generates arithmetic/boundary mutants,
  runs a test suite against each mutant, reports killed/survived/score.

  Usage: lua5.1 examples/mutate.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local os_clock = os.clock
local pcall = pcall
local tostring = tostring
local math_abs = math.abs

log.set_level(log.INFO)
log.set_context("mutate")

-- ----------------------------------------------------------------
-- Subject under test: a pure function to mutate
-- ----------------------------------------------------------------

--- Compute the absolute difference, clamped to a maximum.
--- @param a number
--- @param b number
--- @param max_val number maximum allowed result
--- @return number clamped absolute difference
local function clamped_diff(a, b, max_val)
    local diff = math_abs(a - b)
    if diff > max_val then
        return max_val
    end
    return diff
end

-- ----------------------------------------------------------------
-- Test suite for the subject
-- ----------------------------------------------------------------

--- Each test returns true if the function behaves correctly.
local function test_suite(fn)
    local tests = {
        {
            name = "zero diff",
            fn = function()
                return fn(5, 5, 10) == 0
            end,
        },
        {
            name = "positive diff",
            fn = function()
                return fn(10, 3, 100) == 7
            end,
        },
        {
            name = "negative diff",
            fn = function()
                return fn(3, 10, 100) == 7
            end,
        },
        {
            name = "clamp at max",
            fn = function()
                return fn(100, 0, 50) == 50
            end,
        },
        {
            name = "exactly at max",
            fn = function()
                return fn(50, 0, 50) == 50
            end,
        },
        {
            name = "below max",
            fn = function()
                return fn(49, 0, 50) == 49
            end,
        },
    }

    for i = 1, #tests do
        local ok, result = pcall(tests[i].fn)
        if not ok or not result then
            return false, tests[i].name
        end
    end
    return true, nil
end

-- ----------------------------------------------------------------
-- Mutant generators
-- ----------------------------------------------------------------

--- Generate mutants of clamped_diff by altering its behavior.
--- Each mutant is a function with the same signature.
local function generate_mutants()
    return {
        {
            name = "negate subtraction (a + b)",
            fn = function(a, b, max_val)
                local diff = math_abs(a + b) -- mutation: + instead of -
                if diff > max_val then
                    return max_val
                end
                return diff
            end,
        },
        {
            name = "remove abs (a - b raw)",
            fn = function(a, b, max_val)
                local diff = a - b -- mutation: no abs()
                if diff > max_val then
                    return max_val
                end
                return diff
            end,
        },
        {
            name = "off-by-one clamp (>=)",
            fn = function(a, b, max_val)
                local diff = math_abs(a - b)
                if diff >= max_val then -- mutation: >= instead of >
                    return max_val
                end
                return diff
            end,
        },
        {
            name = "return 0 always",
            fn = function(_a, _b, _max_val)
                return 0 -- mutation: constant return
            end,
        },
        {
            name = "return max always",
            fn = function(_a, _b, max_val)
                return max_val -- mutation: always clamp
            end,
        },
        {
            name = "swap clamp direction (<)",
            fn = function(a, b, max_val)
                local diff = math_abs(a - b)
                if diff < max_val then -- mutation: < instead of >
                    return max_val
                end
                return diff
            end,
        },
        {
            name = "off-by-one result (+1)",
            fn = function(a, b, max_val)
                local diff = math_abs(a - b) + 1 -- mutation: off-by-one
                if diff > max_val then
                    return max_val
                end
                return diff
            end,
        },
    }
end

local function main(_args)
    io.write("Mutation Testing Harness\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- Verify the original function passes all tests first
    io.write("Original function: ")
    local orig_ok, orig_fail = test_suite(clamped_diff)
    if not orig_ok then
        io.write(string_format("FAIL (%s)\n", tostring(orig_fail)))
        log.error("original function fails tests, aborting")
        return 1
    end
    io.write("PASS (all tests green)\n\n")

    -- Generate and test mutants
    local mutants = generate_mutants()

    local c = validate.Checker:new()
    c:check_type(mutants, "table", "mutants")
    c:assert()

    guard.contract(#mutants > 0, "must have at least one mutant")

    io.write(string_format("Testing %d mutants...\n", #mutants))
    io.write(string_rep("-", 50) .. "\n")

    local killed = 0
    local survived = 0
    local start = os_clock()

    for i = 1, #mutants do
        local m = mutants[i]
        local passes, _fail_name = test_suite(m.fn)
        local status
        if passes then
            status = "SURVIVED"
            survived = survived + 1
            log.warn("mutant survived: %s", m.name)
        else
            status = "KILLED"
            killed = killed + 1
        end
        io.write(string_format("  [%s] %s\n", status, m.name))
    end

    local elapsed = os_clock() - start
    local total = killed + survived
    local score = (killed / total) * 100

    io.write(string_rep("-", 50) .. "\n")
    io.write(string_format("Killed:   %d/%d\n", killed, total))
    io.write(string_format("Survived: %d/%d\n", survived, total))
    io.write(string_format("Score:    %.1f%%\n", score))
    io.write(string_format("Elapsed:  %.2f ms\n", elapsed * 1000))

    if score >= 80 then
        log.info("mutation score %.1f%% meets threshold (80%%)", score)
    else
        log.warn("mutation score %.1f%% below threshold (80%%)", score)
    end

    return 0
end

os.exit(main(arg))
