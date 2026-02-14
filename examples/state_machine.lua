#!/usr/bin/env lua5.1
--[[
  state_machine.lua — Example: phase/state machine with timing.
  Demonstrates phase lifecycle tracking (start/pass/fail) with elapsed
  time measurement. Patterns from resolve-pipeline: phase_start,
  phase_pass, phase_fail, state accumulation, summary reporting.

  Usage: lua5.1 examples/state_machine.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local os_clock = os.clock
local tostring = tostring

log.set_level(log.INFO)
log.set_context("pipeline")

-- ----------------------------------------------------------------
-- Phase tracker (mirrors resolve-pipeline's phase lifecycle)
-- ----------------------------------------------------------------

--- Create a new pipeline state object.
--- @param total_phases number expected number of phases
--- @return table state
local function create_state(total_phases)
    guard.assert_type(total_phases, "number", "total_phases")
    guard.contract(total_phases > 0, "total_phases must be positive")
    return {
        results = {},
        timings = {},
        output = {},
        current_phase = 0,
        total_phases = total_phases,
    }
end

--- Mark the start of a new phase.
--- @param state table pipeline state
--- @param name string phase name
local function phase_start(state, name)
    guard.assert_not_nil(state, "state")
    local ok, err = validate.check_string_not_empty(name, "phase_name")
    guard.contract(ok, tostring(err))

    state.current_phase = state.current_phase + 1
    state._phase_clock = os_clock()
    state._phase_name = name

    log.debug("phase %d/%d: %s starting", state.current_phase, state.total_phases, name)
end

--- Mark the current phase as passed.
--- @param state table pipeline state
local function phase_pass(state)
    guard.assert_not_nil(state, "state")
    local elapsed = os_clock() - (state._phase_clock or os_clock())
    local phase = state.current_phase

    state.results[phase] = true
    state.timings[phase] = {
        name = state._phase_name,
        elapsed = elapsed,
        result = "PASS",
    }
    state.output[#state.output + 1] =
        string_format("  Phase %2d: %-30s PASS  (%.2f ms)", phase, state._phase_name, elapsed * 1000)

    log.debug("phase %d: %s passed (%.2f ms)", phase, state._phase_name, elapsed * 1000)
end

--- Mark the current phase as failed.
--- @param state table pipeline state
--- @param reason string|nil failure reason
local function phase_fail(state, reason)
    guard.assert_not_nil(state, "state")
    local elapsed = os_clock() - (state._phase_clock or os_clock())
    local phase = state.current_phase

    state.results[phase] = false
    state.timings[phase] = {
        name = state._phase_name,
        elapsed = elapsed,
        result = "FAIL",
        reason = reason,
    }
    state.output[#state.output + 1] =
        string_format("  Phase %2d: %-30s FAIL  (%.2f ms)", phase, state._phase_name, elapsed * 1000)
    if reason then
        state.output[#state.output + 1] = string_format("           %s", reason)
    end

    log.warn("phase %d: %s failed: %s", phase, state._phase_name, tostring(reason))
end

--- Print summary of all phases.
--- @param state table pipeline state
--- @return boolean all_passed
local function print_summary(state)
    io.write("\nPhase Results:\n")
    io.write(string_rep("-", 60) .. "\n")
    for i = 1, #state.output do
        io.write(string_format("%s\n", state.output[i]))
    end
    io.write(string_rep("-", 60) .. "\n")

    local pass_count = 0
    local fail_count = 0
    local total_elapsed = 0
    for i = 1, state.current_phase do
        if state.results[i] then
            pass_count = pass_count + 1
        else
            fail_count = fail_count + 1
        end
        total_elapsed = total_elapsed + state.timings[i].elapsed -- pmat:ignore CB-601
    end

    io.write(
        string_format(
            "  %d passed, %d failed, %d total (%.2f ms)\n",
            pass_count,
            fail_count,
            pass_count + fail_count,
            total_elapsed * 1000
        )
    )

    -- Property: completeness — did we run expected number of phases?
    local complete = state.current_phase == state.total_phases
    if not complete then
        io.write(string_format("  WARNING: ran %d/%d phases (incomplete)\n", state.current_phase, state.total_phases))
    end

    return fail_count == 0
end

-- ----------------------------------------------------------------
-- Example phase functions (simulate resolve-pipeline stages)
-- ----------------------------------------------------------------

local function phase_validate_config(config)
    local c = validate.Checker.new()
    c:check_string_not_empty(config.project_name, "project_name")
    c:check_type(config.frame_rate, "number", "frame_rate")
    c:check_range(config.frame_rate, 1, 120, "frame_rate")
    return c:ok(), c:ok() and nil or c:errors()[1]
end

local function phase_check_assets(assets)
    for i = 1, #assets do
        local ok, err = validate.check_string_not_empty(assets[i], "asset")
        if not ok then
            return false, string_format("asset[%d]: %s", i, err)
        end
    end
    return true, nil
end

local function phase_compute_work()
    -- Simulate CPU work
    local sum = 0
    for i = 1, 100000 do
        sum = sum + i
    end
    guard.contract(sum > 0, "sum must be positive")
    return true, nil
end

local function phase_intentional_failure()
    return false, "simulated: render engine unavailable"
end

local function main(_args)
    io.write("Phase/State Machine Pipeline\n")
    io.write(string_rep("=", 60) .. "\n\n")

    local config = {
        project_name = "DemoProject",
        frame_rate = 30,
        assets = { "intro.mp4", "main.mp4", "outro.mp4" },
    }

    -- ----------------------------------------------------------------
    -- Pipeline 1: All phases pass
    -- ----------------------------------------------------------------
    io.write("--- Pipeline 1: Success Path ---\n")
    local state = create_state(3)

    phase_start(state, "Validate Configuration")
    local ok, err = phase_validate_config(config)
    if ok then
        phase_pass(state)
    else
        phase_fail(state, err)
    end

    phase_start(state, "Check Assets")
    ok, err = phase_check_assets(config.assets)
    if ok then
        phase_pass(state)
    else
        phase_fail(state, err)
    end

    phase_start(state, "Compute Timeline")
    ok, err = phase_compute_work()
    if ok then
        phase_pass(state)
    else
        phase_fail(state, err)
    end

    local all_ok = print_summary(state)
    log.info("pipeline 1: %s", all_ok and "all passed" or "has failures")

    -- ----------------------------------------------------------------
    -- Pipeline 2: Failure + halt
    -- ----------------------------------------------------------------
    io.write("\n--- Pipeline 2: Failure Path ---\n")
    local state2 = create_state(4)
    local phases = {
        {
            name = "Validate Configuration",
            fn = function()
                return phase_validate_config(config)
            end,
        },
        {
            name = "Check Assets",
            fn = function()
                return phase_check_assets(config.assets)
            end,
        },
        { name = "Render Passes", fn = phase_intentional_failure },
        { name = "Export Timeline", fn = phase_compute_work },
    }

    local halted = false
    for i = 1, #phases do
        if halted then
            break
        end
        phase_start(state2, phases[i].name)
        local p_ok, p_err = phases[i].fn()
        if p_ok then
            phase_pass(state2)
        else
            phase_fail(state2, p_err)
            halted = true
            log.warn("halting pipeline at phase %d", i)
        end
    end

    local all_ok2 = print_summary(state2)
    log.info("pipeline 2: %s", all_ok2 and "all passed" or "has failures")

    return (all_ok and not all_ok2) and 0 or 1
end

os.exit(main(arg))
