#!/usr/bin/env lua5.1
--[[
  closure_patterns.lua — Example: closure and upvalue patterns from real Lua projects.
  Demonstrates factory functions, partial application, memoization via closures,
  shared state between closures, closure-based vs coroutine iterators, and
  pipeline builders — idioms found in AwesomeWM gears.cache, Kong balancer
  factories, and APISIX plugin factories.

  Usage: lua5.1 examples/closure_patterns.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local select = select
local unpack = unpack
local string_format = string.format
local string_rep = string.rep
local table_insert = table.insert
local table_concat = table.concat
local io_write = io.write
local coroutine_wrap = coroutine.wrap
local coroutine_yield = coroutine.yield

log.set_level(log.INFO)
log.set_context("closures")

local function banner(title)
    io_write("\n" .. string_rep("=", 60) .. "\n")
    io_write("  " .. title .. "\n")
    io_write(string_rep("=", 60) .. "\n\n")
end

local function section(title)
    io_write("--- " .. title .. " ---\n")
end

-- ============================================================
-- Pattern 1: Factory Function (AwesomeWM, Kong)
-- make_validator(rules) returns a validation function that
-- captures the rules table as an upvalue.
-- ============================================================

--- Create a record validator from a rules table.
--- Rules map field names to expected type strings.
--- @param rules table field-name -> type-name mapping
--- @return function validator(record) -> boolean, string|nil
local function make_validator(rules)
    guard.assert_type(rules, "table", "rules")
    -- Snapshot rules at creation time (upvalue capture)
    local frozen_rules = {}
    for field, expected_type in pairs(rules) do
        guard.assert_type(field, "string", "field")
        guard.assert_type(expected_type, "string", "expected_type")
        frozen_rules[field] = expected_type
    end
    log.debug("created validator with %d rules", 0) -- count below
    local count = 0
    for _ in pairs(frozen_rules) do
        count = count + 1
    end
    log.info("validator factory: created validator with %d rules", count)

    return function(record)
        guard.assert_type(record, "table", "record")
        local c = validate.Checker:new()
        for field, expected_type in pairs(frozen_rules) do
            c:check_type(record[field], expected_type, field)
        end
        if c:ok() then
            return true, nil
        end
        local errs = c:errors()
        return false, table_concat(errs, "; ")
    end
end

local function demo_factory()
    banner("Pattern 1: Factory Function (AwesomeWM, Kong)")

    local rules = { name = "string", age = "number", email = "string" }
    local validate_user = make_validator(rules)

    section("Valid record")
    local valid = { name = "Alice", age = 30, email = "alice@example.com" }
    local ok, err = validate_user(valid)
    io_write(string_format("  valid: ok=%s err=%s\n", tostring(ok), tostring(err)))

    section("Invalid record (wrong types)")
    local invalid = { name = 42, age = "thirty", email = true }
    ok, err = validate_user(invalid)
    io_write(string_format("  invalid: ok=%s err=%s\n", tostring(ok), tostring(err)))

    section("Missing fields")
    local partial_rec = { name = "Bob" }
    ok, err = validate_user(partial_rec)
    io_write(string_format("  partial: ok=%s err=%s\n\n", tostring(ok), tostring(err)))
end

-- ============================================================
-- Pattern 2: Partial Application
-- partial(fn, ...) returns a function with pre-filled args.
-- ============================================================

--- Create a partially applied function.
--- Captures fn and the first arguments as upvalues.
--- @param fn function the function to partially apply
--- @param ... any arguments to pre-fill
--- @return function that appends remaining args and calls fn
local function partial(fn, ...)
    guard.assert_type(fn, "function", "fn")
    local bound_n = select("#", ...)
    local bound = { ... }
    log.debug("partial: binding %d arguments", bound_n)

    return function(...)
        local extra_n = select("#", ...)
        local extra = { ... }
        local args = {}
        for i = 1, bound_n do
            args[i] = bound[i]
        end
        for i = 1, extra_n do
            args[bound_n + i] = extra[i]
        end
        return fn(unpack(args, 1, bound_n + extra_n))
    end
end

local function demo_partial_application()
    banner("Pattern 2: Partial Application")

    section("Partial add")
    local function add(a, b)
        guard.assert_type(a, "number", "a")
        guard.assert_type(b, "number", "b")
        return a + b
    end
    local add10 = partial(add, 10)
    io_write(string_format("  add10(5)  = %d\n", add10(5)))
    io_write(string_format("  add10(20) = %d\n", add10(20)))

    section("Partial format")
    local log_line = partial(string_format, "[%s] %s: %s")
    local msg1 = log_line("INFO", "server", "started")
    io_write(string_format('  log_line("INFO", "server", "started") = %s\n', msg1))
    local msg2 = log_line("ERR", "db", "timeout")
    io_write(string_format('  log_line("ERR", "db", "timeout")     = %s\n\n', msg2))
end

-- ============================================================
-- Pattern 3: Memoize via Closure (AwesomeWM gears.cache)
-- memoize(fn) returns a caching wrapper with an internal
-- cache table as upvalue.
-- ============================================================

--- Create a memoized wrapper for a single-argument function.
--- Uses tostring of the argument as cache key.
--- @param fn function single-argument function to memoize
--- @return function memoized wrapper
--- @return function cache_info() returns hit/miss counts
local function memoize(fn)
    guard.assert_type(fn, "function", "fn")
    local cache = {}
    local hits = 0
    local misses = 0

    local function wrapper(arg)
        local key = tostring(arg)
        if cache[key] ~= nil then
            hits = hits + 1
            log.debug("memoize: cache hit for key=%s", key)
            return cache[key]
        end
        misses = misses + 1
        log.debug("memoize: cache miss for key=%s", key)
        local result = fn(arg)
        cache[key] = result
        return result
    end

    local function cache_info()
        return hits, misses
    end

    return wrapper, cache_info
end

local function demo_memoize()
    banner("Pattern 3: Memoize via Closure (gears.cache)")

    local call_count = 0
    local function expensive_square(n)
        guard.assert_type(n, "number", "n")
        call_count = call_count + 1
        -- Simulate expensive computation
        local result = n * n
        return result
    end

    local memo_square, cache_info = memoize(expensive_square)

    section("First calls (cache misses)")
    io_write(string_format("  square(4)  = %d\n", memo_square(4)))
    io_write(string_format("  square(7)  = %d\n", memo_square(7)))
    io_write(string_format("  square(12) = %d\n", memo_square(12)))

    section("Repeated calls (cache hits)")
    io_write(string_format("  square(4)  = %d\n", memo_square(4)))
    io_write(string_format("  square(7)  = %d\n", memo_square(7)))
    io_write(string_format("  square(4)  = %d\n", memo_square(4)))

    local h, m = cache_info()
    io_write(string_format("\n  Cache stats: hits=%d misses=%d\n", h, m))
    io_write(string_format("  Actual fn calls: %d (saved %d)\n\n", call_count, (h + m) - call_count))
end

-- ============================================================
-- Pattern 4: Shared State Between Closures
-- make_counter(initial) returns a table of functions that
-- all share the same upvalue for state.
-- ============================================================

--- Create a counter module with shared upvalue state.
--- All returned functions close over the same count variable.
--- @param initial number starting value (default 0)
--- @return table with increment, decrement, get, reset functions
local function make_counter(initial)
    local c = validate.Checker:new()
    c:check_type(initial, "number", "initial")
    c:assert()

    local count = initial
    log.info("counter created with initial=%d", initial)

    local api = {}

    function api.increment(n)
        n = n or 1
        guard.assert_type(n, "number", "n")
        count = count + n
        return count
    end

    function api.decrement(n)
        n = n or 1
        guard.assert_type(n, "number", "n")
        count = count - n
        return count
    end

    function api.get()
        return count
    end

    function api.reset()
        count = initial
        return count
    end

    return api
end

local function demo_shared_state()
    banner("Pattern 4: Shared State (Counter Module)")

    local counter = make_counter(0)

    section("Increment")
    io_write(string_format("  increment()  -> %d\n", counter.increment()))
    io_write(string_format("  increment()  -> %d\n", counter.increment()))
    io_write(string_format("  increment(5) -> %d\n", counter.increment(5)))

    section("Decrement")
    io_write(string_format("  decrement()  -> %d\n", counter.decrement()))
    io_write(string_format("  decrement(3) -> %d\n", counter.decrement(3)))

    section("Get and reset")
    io_write(string_format("  get()   -> %d\n", counter.get()))
    io_write(string_format("  reset() -> %d\n", counter.reset()))
    io_write(string_format("  get()   -> %d\n\n", counter.get()))
end

-- ============================================================
-- Pattern 5: Closure-Based Iterator vs Coroutine Iterator
-- Two approaches to stateful iteration compared side by side.
-- ============================================================

--- Range iterator using closure with upvalue state.
--- @param start number
--- @param stop number
--- @param step number (default 1)
--- @return function iterator
local function range_closure(start, stop, step)
    guard.assert_type(start, "number", "start")
    guard.assert_type(stop, "number", "stop")
    step = step or 1
    guard.assert_type(step, "number", "step")
    guard.contract(step ~= 0, "step must not be zero")

    local current = start - step -- upvalue: mutable state
    return function()
        current = current + step
        if (step > 0 and current <= stop) or (step < 0 and current >= stop) then
            return current
        end
        return nil
    end
end

--- Range iterator using coroutine.wrap.
--- @param start number
--- @param stop number
--- @param step number (default 1)
--- @return function iterator
local function range_coroutine(start, stop, step)
    guard.assert_type(start, "number", "start")
    guard.assert_type(stop, "number", "stop")
    step = step or 1
    guard.assert_type(step, "number", "step")
    guard.contract(step ~= 0, "step must not be zero")

    return coroutine_wrap(function()
        local current = start
        while (step > 0 and current <= stop) or (step < 0 and current >= stop) do
            coroutine_yield(current)
            current = current + step
        end
    end)
end

local function demo_iterators()
    banner("Pattern 5: Closure vs Coroutine Iterators")

    section("Closure-based range(1, 5)")
    local parts = {}
    for val in range_closure(1, 5, 1) do
        parts[#parts + 1] = tostring(val)
    end
    io_write("  " .. table_concat(parts, ", ") .. "\n")

    section("Coroutine-based range(1, 5)")
    parts = {}
    for val in range_coroutine(1, 5, 1) do
        parts[#parts + 1] = tostring(val)
    end
    io_write("  " .. table_concat(parts, ", ") .. "\n")

    section("Countdown range(10, 1, -3)")
    local closure_parts = {}
    for val in range_closure(10, 1, -3) do
        closure_parts[#closure_parts + 1] = tostring(val)
    end
    local coro_parts = {}
    for val in range_coroutine(10, 1, -3) do
        coro_parts[#coro_parts + 1] = tostring(val)
    end
    io_write(string_format("  closure:   %s\n", table_concat(closure_parts, ", ")))
    io_write(string_format("  coroutine: %s\n", table_concat(coro_parts, ", ")))

    -- Verify both produce identical results
    local match = table_concat(closure_parts, ",") == table_concat(coro_parts, ",")
    io_write(string_format("  identical: %s\n\n", tostring(match)))
end

-- ============================================================
-- Pattern 6: Pipeline Builder (APISIX plugin chain)
-- pipeline() returns a chainable builder that accumulates
-- transformation steps as upvalues.
-- ============================================================

--- Create a pipeline builder.
--- Steps are stored in an upvalue array; :add() appends,
--- :run() feeds input through all steps sequentially.
--- @return table builder with add(fn) and run(input) methods
local function pipeline()
    local steps = {} -- upvalue: accumulated transformations

    local builder = {}
    local builder_mt = { __index = builder }
    setmetatable(builder, builder_mt)

    --- Add a transformation step to the pipeline.
    --- @param fn function transformation function
    --- @return table self for chaining
    function builder:add(fn)
        guard.assert_type(fn, "function", "fn")
        table_insert(steps, fn)
        log.debug("pipeline: added step %d", #steps)
        return self
    end

    --- Run the pipeline, feeding input through all steps.
    --- @param input any initial input value
    --- @return any final transformed value
    function builder:run(input)
        guard.contract(#steps > 0, "pipeline has no steps")
        local value = input
        for i = 1, #steps do
            value = steps[i](value)
        end
        return value
    end

    --- Return the number of steps in the pipeline.
    --- @return number
    function builder:len()
        return #steps
    end

    return builder
end

local function demo_pipeline()
    banner("Pattern 6: Pipeline Builder (APISIX)")

    section("String transformation pipeline")
    local p = pipeline()
    p:add(function(s)
        guard.assert_type(s, "string", "s")
        return s:lower()
    end)
    p:add(function(s)
        return s:gsub("%s+", "_")
    end)
    p:add(function(s)
        return s:gsub("[^%w_]", "")
    end)

    local input = "  Hello, World!  Welcome to Lua.  "
    local result = p:run(input)
    io_write(string_format("  input:  %q\n", input))
    io_write(string_format("  output: %q\n", result))
    io_write(string_format("  steps:  %d\n", p:len()))

    section("Numeric pipeline")
    local np = pipeline()
    np:add(function(n)
        guard.assert_type(n, "number", "n")
        return n * 2
    end)
    np:add(function(n)
        return n + 10
    end)
    np:add(function(n)
        return n * n
    end)

    io_write(string_format("  pipeline(5): (5*2 + 10)^2 = %d\n", np:run(5)))
    io_write(string_format("  pipeline(3): (3*2 + 10)^2 = %d\n\n", np:run(3)))
end

-- ============================================================
-- Main
-- ============================================================

local function main(_args)
    io_write("Closure Patterns\n")
    io_write(string_rep("=", 60) .. "\n")
    io_write("Six patterns demonstrating closures and upvalues in Lua.\n")
    io_write("Source: AwesomeWM gears.cache, Kong balancers, APISIX plugins.\n")

    demo_factory()
    demo_partial_application()
    demo_memoize()
    demo_shared_state()
    demo_iterators()
    demo_pipeline()

    io_write(string_rep("=", 60) .. "\n")
    io_write("All closure patterns demonstrated successfully.\n")

    return 0
end

os.exit(main(arg))
