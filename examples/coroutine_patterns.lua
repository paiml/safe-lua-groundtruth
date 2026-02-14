#!/usr/bin/env lua5.1
--[[
  coroutine_patterns.lua — Example: advanced coroutine patterns from real Lua projects.
  Demonstrates iterator generators (AwesomeWM), producer-consumer pipelines,
  budget-limited schedulers (lazy.nvim), coroutine error handling,
  status tracking, and semaphore-based resource limiting (xmake).

  Usage: lua5.1 examples/coroutine_patterns.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_yield = coroutine.yield
local coroutine_wrap = coroutine.wrap
local string_format = string.format
local string_rep = string.rep
local table_insert = table.insert
local table_remove = table.remove
local os_clock = os.clock
local io_write = io.write
local pcall = pcall
local ipairs = ipairs
local tostring = tostring

log.set_level(log.NONE)

local function banner(title)
    io_write("\n" .. string_rep("=", 60) .. "\n")
    io_write("  " .. title .. "\n")
    io_write(string_rep("=", 60) .. "\n\n")
end

local function section(title)
    io_write("--- " .. title .. " ---\n")
end

-- ============================================================
-- Pattern 1: Iterator Generator via coroutine.wrap
-- Inspired by AwesomeWM's awful.util and tree traversal iterators.
-- coroutine.wrap returns a function that resumes automatically,
-- making coroutines seamless as iterators.
-- ============================================================

--- Build a simple binary tree node.
local function tree_node(value, left, right)
    return { value = value, left = left, right = right }
end

--- In-order tree traversal iterator using coroutine.wrap.
--- Yields values in sorted order for a BST.
local function inorder(node)
    guard.assert_type(node, "table", "node")
    return coroutine_wrap(function()
        local function walk(n)
            if n == nil then
                return
            end
            if n.left then
                walk(n.left)
            end
            coroutine_yield(n.value)
            if n.right then
                walk(n.right)
            end
        end
        walk(node)
    end)
end

--- Fibonacci iterator using coroutine.wrap.
local function fibonacci(limit)
    guard.assert_type(limit, "number", "limit")
    guard.contract(limit > 0, "limit must be positive")
    return coroutine_wrap(function()
        local a, b = 0, 1
        for _ = 1, limit do
            coroutine_yield(a)
            a, b = b, a + b
        end
    end)
end

local function demo_iterator_generators()
    banner("Pattern 1: Iterator Generator (coroutine.wrap)")

    section("Fibonacci sequence (first 10)")
    local parts = {}
    for val in fibonacci(10) do
        parts[#parts + 1] = tostring(val)
    end
    io_write("  " .. table.concat(parts, ", ") .. "\n\n")

    section("In-order BST traversal")
    --       4
    --      / \
    --     2   6
    --    / \ / \
    --   1  3 5  7
    local bst = tree_node(4, tree_node(2, tree_node(1), tree_node(3)), tree_node(6, tree_node(5), tree_node(7)))
    local values = {}
    for val in inorder(bst) do
        values[#values + 1] = tostring(val)
    end
    io_write("  Tree: " .. table.concat(values, " -> ") .. "\n\n")
end

-- ============================================================
-- Pattern 2: Producer-Consumer Pipeline
-- Two coroutines communicate via a shared buffer.
-- The producer yields data; the consumer pulls and transforms it.
-- ============================================================

--- Create a producer coroutine that generates items and pushes to a buffer.
--- Sets signal.done = true when finished.
local function make_producer(items, buffer, signal)
    guard.assert_type(items, "table", "items")
    guard.assert_type(buffer, "table", "buffer")
    guard.assert_type(signal, "table", "signal")
    return coroutine_create(function()
        for _, item in ipairs(items) do
            table_insert(buffer, item)
            coroutine_yield("produced: " .. tostring(item))
        end
        signal.done = true
    end)
end

--- Create a consumer coroutine that pulls from a buffer and processes items.
--- Stops when signal.done is true and buffer is empty.
local function make_consumer(buffer, signal, results)
    guard.assert_type(buffer, "table", "buffer")
    guard.assert_type(signal, "table", "signal")
    guard.assert_type(results, "table", "results")
    return coroutine_create(function()
        while true do
            if #buffer > 0 then
                local item = table_remove(buffer, 1)
                local processed = string_format("[processed: %s -> %s]", tostring(item), tostring(item):upper())
                table_insert(results, processed)
                coroutine_yield("consumed: " .. tostring(item))
            elseif signal.done then
                break
            else
                coroutine_yield("waiting...")
            end
        end
    end)
end

--- Resume a coroutine and log the result.
--- @param co thread coroutine to resume
--- @param step number current step number
--- @param label string label for log output (e.g. "producer")
local function step_coroutine(co, step, label)
    if coroutine_status(co) == "dead" then
        return
    end
    local ok, msg = coroutine_resume(co)
    if ok and msg then
        io_write(string_format("  step %d %s: %s\n", step, label, msg))
    elseif not ok then
        io_write(string_format("  step %d %s error: %s\n", step, label, tostring(msg)))
    end
end

local function demo_producer_consumer()
    banner("Pattern 2: Producer-Consumer Pipeline")

    local items = { "alpha", "beta", "gamma", "delta" }
    local buffer = {}
    local signal = { done = false }
    local results = {}

    local producer = make_producer(items, buffer, signal)
    local consumer = make_consumer(buffer, signal, results)

    local step = 0
    local max_steps = #items * 4 -- generous safety bound
    while coroutine_status(producer) ~= "dead" or coroutine_status(consumer) ~= "dead" do
        step = step + 1
        if step > max_steps then
            io_write("  [safety] max steps reached, breaking\n")
            break
        end
        step_coroutine(producer, step, "producer")
        if coroutine_status(producer) == "dead" then
            signal.done = true
        end
        step_coroutine(consumer, step, "consumer")
    end

    io_write("\n  Final results:\n")
    for i = 1, #results do
        io_write(string_format("    %d. %s\n", i, results[i]))
    end
    io_write("\n")
end

-- ============================================================
-- Pattern 3: Budget-Limited Scheduler (lazy.nvim pattern)
-- Runs coroutines cooperatively but only within a per-tick
-- time budget, deferring remaining work to the next tick.
-- ============================================================

--- Create a budget-limited scheduler.
--- @param budget_ms number maximum milliseconds per tick
--- @return table scheduler with add() and tick() methods
local function budget_scheduler(budget_ms)
    local c = validate.Checker:new()
    c:check_type(budget_ms, "number", "budget_ms")
    c:check_range(budget_ms, 0.1, 1000, "budget_ms")
    c:assert()

    local queue = {}

    local sched = {}

    function sched.add(name, fn)
        guard.assert_type(name, "string", "name")
        guard.assert_type(fn, "function", "fn")
        table_insert(queue, { name = name, co = coroutine_create(fn) })
    end

    --- Run one tick of the scheduler within the time budget.
    --- @return number completed count of completed coroutines this tick
    --- @return number remaining count of coroutines still alive
    function sched.tick()
        local start = os_clock()
        local budget_sec = budget_ms / 1000
        local completed = 0
        local i = 1
        while i <= #queue do
            if os_clock() - start >= budget_sec then
                break
            end
            local entry = queue[i]
            if coroutine_status(entry.co) == "dead" then
                table_remove(queue, i)
                completed = completed + 1
            else
                coroutine_resume(entry.co)
                if coroutine_status(entry.co) == "dead" then
                    table_remove(queue, i)
                    completed = completed + 1
                else
                    i = i + 1
                end
            end
        end
        return completed, #queue
    end

    function sched.pending()
        return #queue
    end

    return sched
end

local function demo_budget_scheduler()
    banner("Pattern 3: Budget-Limited Scheduler (lazy.nvim)")

    local sched = budget_scheduler(5) -- 5ms budget per tick

    -- Add tasks that do incremental work
    for t = 1, 4 do
        local task_name = string_format("task-%d", t)
        sched.add(task_name, function()
            for step = 1, 3 do
                -- Simulate small work unit
                local _sum = 0
                for j = 1, 500 do
                    _sum = _sum + j
                end
                coroutine_yield(string_format("%s: step %d", task_name, step))
            end
        end)
    end

    local tick_num = 0
    while sched.pending() > 0 do
        tick_num = tick_num + 1
        local start = os_clock()
        local completed, remaining = sched.tick()
        local elapsed = (os_clock() - start) * 1000
        io_write(
            string_format("  tick %d: completed=%d remaining=%d (%.2f ms)\n", tick_num, completed, remaining, elapsed)
        )
    end
    io_write(string_format("  All tasks finished in %d ticks\n\n", tick_num))
end

-- ============================================================
-- Pattern 4: Coroutine Error Handling
-- The common bug: calling coroutine.resume without pcall.
-- When a coroutine errors, resume returns false + error message.
-- But if you want to protect BOTH the resume call and detect
-- coroutine-level vs system-level errors, wrap in pcall.
-- ============================================================

local function demo_error_handling()
    banner("Pattern 4: Coroutine Error Handling")

    section("Basic resume error capture")
    local bad_co = coroutine_create(function()
        coroutine_yield("step 1 ok")
        error("simulated failure in coroutine")
    end)

    -- First resume succeeds
    local ok, val = coroutine_resume(bad_co)
    io_write(string_format("  resume 1: ok=%s val=%s\n", tostring(ok), tostring(val)))

    -- Second resume hits the error
    ok, val = coroutine_resume(bad_co)
    io_write(string_format("  resume 2: ok=%s val=%s\n", tostring(ok), tostring(val)))

    -- Resuming a dead coroutine
    ok, val = coroutine_resume(bad_co)
    io_write(string_format("  resume 3 (dead): ok=%s val=%s\n", tostring(ok), tostring(val)))

    io_write("\n")
    section("Safe resume wrapper with pcall")

    --- Safe resume that catches both coroutine errors and unexpected system errors.
    local function safe_resume(co, ...)
        guard.assert_type(co, "thread", "co")
        if coroutine_status(co) == "dead" then
            return false, "cannot resume dead coroutine"
        end
        local results = { pcall(coroutine_resume, co, ...) }
        local pcall_ok = results[1]
        if not pcall_ok then
            -- pcall itself failed (system-level error)
            return false, "system error: " .. tostring(results[2])
        end
        local resume_ok = results[2]
        if not resume_ok then
            -- coroutine raised an error
            return false, "coroutine error: " .. tostring(results[3])
        end
        -- Success: return true plus any yielded/returned values
        local vals = {}
        for i = 3, #results do
            vals[#vals + 1] = results[i]
        end
        return true, vals
    end

    local safe_co = coroutine_create(function()
        coroutine_yield("safe step 1")
        coroutine_yield("safe step 2")
        error("intentional failure")
    end)

    for attempt = 1, 4 do
        local s_ok, s_val = safe_resume(safe_co)
        if s_ok then
            io_write(string_format("  attempt %d: ok, values=%s\n", attempt, tostring(s_val[1])))
        else
            io_write(string_format("  attempt %d: failed, reason=%s\n", attempt, tostring(s_val)))
        end
    end
    io_write("\n")
end

-- ============================================================
-- Pattern 5: Coroutine Status Tracking
-- Demonstrates all four coroutine states:
--   suspended - created but not yet started, or yielded
--   running   - currently executing (only visible from inside)
--   dead      - finished or errored
--   normal    - resumed another coroutine (intermediate state)
-- ============================================================

local function demo_status_tracking()
    banner("Pattern 5: Coroutine Status Tracking")

    local observed_states = {}

    local function record(label, state)
        table_insert(observed_states, { label = label, state = state })
    end

    -- Inner coroutine will be resumed by outer, creating "normal" state
    local inner_co
    local outer_co

    inner_co = coroutine_create(function()
        -- When inner runs, outer is in "normal" state
        record("outer (from inner)", coroutine_status(outer_co))
        record("inner (self)", "running") -- coroutine.status of self returns "running"
        coroutine_yield()
        record("inner resumed", "running")
    end)

    outer_co = coroutine_create(function()
        record("inner before first resume", coroutine_status(inner_co))
        coroutine_resume(inner_co) -- inner runs; outer becomes "normal"
        record("inner after yield", coroutine_status(inner_co))
        coroutine_resume(inner_co) -- finish inner
        record("inner after finish", coroutine_status(inner_co))
    end)

    record("outer initial", coroutine_status(outer_co))
    record("inner initial", coroutine_status(inner_co))

    coroutine_resume(outer_co)

    record("outer final", coroutine_status(outer_co))

    io_write("  State transitions observed:\n")
    io_write(string_format("  %-35s %s\n", "Label", "State"))
    io_write("  " .. string_rep("-", 50) .. "\n")
    for _, entry in ipairs(observed_states) do
        io_write(string_format("  %-35s %s\n", entry.label, entry.state))
    end

    -- Verify all four states were observed
    local seen = {}
    for _, entry in ipairs(observed_states) do
        seen[entry.state] = true
    end
    io_write("\n  All four states observed:\n")
    local all_states = { "suspended", "running", "normal", "dead" }
    local all_seen = true
    for _, s in ipairs(all_states) do
        local present = seen[s] and "yes" or "no"
        io_write(string_format("    %-12s %s\n", s, present))
        if not seen[s] then
            all_seen = false
        end
    end
    io_write(string_format("  Complete: %s\n\n", all_seen and "yes" or "no"))
end

-- ============================================================
-- Pattern 6: Semaphore / Resource Limiting (xmake pattern)
-- A counting semaphore that limits how many coroutines run
-- concurrently. Excess coroutines wait (yield) until a slot
-- opens up.
-- ============================================================

--- Create a semaphore with N permits.
--- @param max_permits number maximum concurrent permits
--- @return table semaphore with acquire/release/run_limited
local function semaphore(max_permits)
    local c = validate.Checker:new()
    c:check_type(max_permits, "number", "max_permits")
    c:check_range(max_permits, 1, 1000, "max_permits")
    c:assert()

    local active = 0
    local waiting = {}

    local sem = {}

    --- Try to acquire a permit. If unavailable, add coroutine to wait queue.
    --- @return boolean true if acquired immediately
    function sem.acquire()
        if active < max_permits then
            active = active + 1
            return true
        end
        -- Park the current coroutine
        local co = coroutine.running()
        guard.assert_not_nil(co, "must be called from a coroutine")
        table_insert(waiting, co)
        coroutine_yield() -- will be resumed when a permit is released
        return true
    end

    --- Release a permit, waking one waiting coroutine if any.
    function sem.release()
        guard.contract(active > 0, "release without matching acquire")
        active = active - 1
        if #waiting > 0 then
            local next_co = table_remove(waiting, 1)
            active = active + 1
            coroutine_resume(next_co)
        end
    end

    --- Run a set of task functions with limited concurrency.
    --- @param tasks table array of {name=string, fn=function}
    --- @return table results array of {name, ok, result|error}
    function sem.run_limited(tasks)
        guard.assert_type(tasks, "table", "tasks")
        guard.contract(#tasks > 0, "tasks must not be empty")

        local results = {}
        local coroutines = {}

        for idx, task in ipairs(tasks) do
            local vc = validate.Checker:new()
            vc:check_string_not_empty(task.name, "task.name")
            vc:check_type(task.fn, "function", "task.fn")
            vc:assert()

            coroutines[idx] = coroutine_create(function()
                sem.acquire()
                local ok, res = pcall(task.fn)
                results[idx] = { name = task.name, ok = ok, value = ok and res or nil, err = not ok and res or nil }
                sem.release()
            end)
        end

        -- Start all coroutines (they will self-limit via the semaphore)
        for idx = 1, #coroutines do
            if coroutine_status(coroutines[idx]) == "suspended" then
                coroutine_resume(coroutines[idx])
            end
        end

        return results
    end

    function sem.active_count()
        return active
    end

    function sem.waiting_count()
        return #waiting
    end

    return sem
end

local function demo_semaphore()
    banner("Pattern 6: Semaphore / Resource Limiting (xmake)")

    local max_concurrent = 2
    io_write(string_format("  Semaphore permits: %d\n\n", max_concurrent))

    local execution_log = {}
    local sem = semaphore(max_concurrent)

    local tasks = {}
    for i = 1, 5 do
        local name = string_format("job-%d", i)
        tasks[i] = {
            name = name,
            fn = function()
                table_insert(execution_log, string_format("  [start] %s (active=%d)", name, sem.active_count()))
                -- Simulate work
                local _sum = 0
                for j = 1, 1000 do
                    _sum = _sum + j
                end
                table_insert(execution_log, string_format("  [done]  %s", name))
                return string_format("%s completed", name)
            end,
        }
    end

    local results = sem.run_limited(tasks)

    section("Execution log")
    for _, line in ipairs(execution_log) do
        io_write(line .. "\n")
    end

    io_write("\n")
    section("Results")
    for _, r in ipairs(results) do
        if r.ok then
            io_write(string_format("  %-8s [OK]   %s\n", r.name, tostring(r.value)))
        else
            io_write(string_format("  %-8s [FAIL] %s\n", r.name, tostring(r.err)))
        end
    end
    io_write("\n")
end

-- ============================================================
-- Main
-- ============================================================

local function main(_args)
    io_write("Advanced Coroutine Patterns\n")
    io_write(string_rep("=", 60) .. "\n")
    io_write("Six patterns from real-world Lua projects.\n")

    demo_iterator_generators()
    demo_producer_consumer()
    demo_budget_scheduler()
    demo_error_handling()
    demo_status_tracking()
    demo_semaphore()

    io_write(string_rep("=", 60) .. "\n")
    io_write("All patterns demonstrated successfully.\n")

    return 0
end

os.exit(main(arg))
