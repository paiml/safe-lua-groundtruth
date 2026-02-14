#!/usr/bin/env lua5.1
--[[
  parallel.lua — Example: coroutine-based job scheduler.
  Dispatches multiple tasks via coroutines, round-robins execution,
  and collects results. Demonstrates Lua 5.1 coroutine patterns
  with safe-lua validation and logging.

  Usage: lua5.1 examples/parallel.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_yield = coroutine.yield
local string_format = string.format
local string_rep = string.rep
local os_clock = os.clock

log.set_level(log.INFO)
log.set_context("scheduler")

--- A cooperative task that yields progress updates.
local function make_task(name, steps)
    return function()
        for i = 1, steps do
            -- Simulate work
            local result = 0
            for j = 1, 1000 do
                result = result + j
            end
            coroutine_yield(string_format("%s: step %d/%d (sum=%d)", name, i, steps, result))
        end
        return string_format("%s: completed all %d steps", name, steps)
    end
end

--- Round-robin scheduler that runs coroutines cooperatively.
local function scheduler(tasks)
    guard.assert_type(tasks, "table", "tasks")
    guard.contract(#tasks > 0, "tasks must not be empty")

    local coros = {}
    local names = {}
    for i = 1, #tasks do
        local c = validate.Checker.new()
        c:check_string_not_empty(tasks[i].name, "task.name")
        c:check_type(tasks[i].fn, "function", "task.fn")
        c:assert()

        coros[i] = coroutine_create(tasks[i].fn)
        names[i] = tasks[i].name
    end

    local results = {}
    local active = #coros
    local round = 0

    log.info("scheduling %d tasks", active)

    while active > 0 do
        round = round + 1
        for i = 1, #coros do
            if coroutine_status(coros[i]) ~= "dead" then
                local ok, value = coroutine_resume(coros[i])
                if not ok then
                    log.error("task %s failed: %s", names[i], tostring(value))
                    results[i] = { ok = false, error = value }
                    active = active - 1
                elseif coroutine_status(coros[i]) == "dead" then
                    -- Final return value
                    results[i] = { ok = true, result = value }
                    active = active - 1
                    log.debug("task %s finished", names[i])
                else
                    -- Yielded progress
                    log.debug("round %d: %s", round, tostring(value))
                end
            end
        end
    end

    log.info("all tasks completed after %d rounds", round)
    return results
end

local function main(_args)
    io.write("Coroutine Job Scheduler\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- Define tasks with varying step counts
    local tasks = {
        { name = "build", fn = make_task("build", 3) },
        { name = "test", fn = make_task("test", 5) },
        { name = "lint", fn = make_task("lint", 2) },
        { name = "docs", fn = make_task("docs", 4) },
    }

    local start = os_clock()
    local results = scheduler(tasks)
    local elapsed = os_clock() - start

    -- Report results
    io.write("\nResults:\n")
    io.write(string_rep("-", 50) .. "\n")
    local all_ok = true
    for i = 1, #tasks do
        local r = results[i]
        local status = r.ok and "OK" or "FAIL"
        local detail = r.ok and r.result or r.error
        io.write(string_format("  %-8s [%s] %s\n", tasks[i].name, status, tostring(detail)))
        if not r.ok then
            all_ok = false
        end
    end

    io.write(string_rep("-", 50) .. "\n")
    io.write(string_format("Elapsed: %.2f ms\n", elapsed * 1000))
    io.write(string_format("Status: %s\n", all_ok and "all tasks succeeded" or "some tasks failed"))

    return all_ok and 0 or 1
end

os.exit(main(arg))
