#!/usr/bin/env lua5.1
--[[
  orchestrate.lua — Example: shell pipeline orchestrator.
  Multi-stage pipeline runner (like a mini CI). Defines a DAG of steps,
  executes in order via shell.exec, logs each step, halts on failure,
  reports summary.

  Usage: lua5.1 examples/orchestrate.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local shell = require("safe.shell")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local os_clock = os.clock
local table_concat = table.concat

log.set_level(log.INFO)
log.set_context("pipeline")

--- A pipeline step definition.
--- @param name string step name
--- @param program string program to execute
--- @param args table|nil arguments
--- @return table step
local function step(name, program, args)
    local c = validate.Checker:new()
    c:check_string_not_empty(name, "name")
    c:check_string_not_empty(program, "program")
    c:assert()
    return {
        name = name,
        program = program,
        args = args or {},
    }
end

--- Execute a pipeline: ordered list of steps, halt on first failure.
--- @param steps table array of step definitions
--- @param dry_run boolean if true, only print commands without executing
--- @return boolean ok, table results
local function run_pipeline(steps, dry_run)
    guard.assert_type(steps, "table", "steps")
    guard.contract(#steps > 0, "pipeline must have at least one step")

    local results = {}
    local all_ok = true

    io.write(string_format("Pipeline: %d steps%s\n", #steps, dry_run and " (dry run)" or ""))
    io.write(string_rep("-", 50) .. "\n")

    for i = 1, #steps do
        local s = steps[i]
        local cmd = shell.build_command(s.program, s.args)
        local start = os_clock()

        io.write(string_format("[%d/%d] %s", i, #steps, s.name))

        if dry_run then
            io.write(string_format(" -> %s (skipped)\n", cmd))
            results[i] = { name = s.name, ok = true, elapsed = 0, dry_run = true }
        else
            log.info("step %d/%d: %s -> %s", i, #steps, s.name, cmd)
            local ok, _code = shell.exec(s.program, s.args)
            local elapsed = os_clock() - start

            results[i] = { name = s.name, ok = ok, elapsed = elapsed }

            if ok then
                io.write(string_format(" [OK] (%.2f ms)\n", elapsed * 1000))
                log.info("step %s passed (%.2f ms)", s.name, elapsed * 1000)
            else
                io.write(string_format(" [FAIL] (%.2f ms)\n", elapsed * 1000))
                log.error("step %s failed, halting pipeline", s.name)
                all_ok = false
                break
            end
        end
    end

    return all_ok, results
end

--- Print a summary table of results.
local function print_summary(results)
    io.write("\nSummary:\n")
    io.write(string_rep("-", 50) .. "\n")
    local pass, fail, skip = 0, 0, 0
    for i = 1, #results do
        local r = results[i]
        local status
        if r.dry_run then
            status = "SKIP"
            skip = skip + 1
        elseif r.ok then
            status = "PASS"
            pass = pass + 1
        else
            status = "FAIL"
            fail = fail + 1
        end
        io.write(string_format("  %-20s [%s]\n", r.name, status))
    end
    io.write(string_rep("-", 50) .. "\n")

    local parts = {}
    parts[#parts + 1] = string_format("%d passed", pass)
    if fail > 0 then
        parts[#parts + 1] = string_format("%d failed", fail)
    end
    if skip > 0 then
        parts[#parts + 1] = string_format("%d skipped", skip)
    end
    io.write(table_concat(parts, ", ") .. "\n")
end

local function main(_args)
    io.write("Shell Pipeline Orchestrator\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- Define a pipeline that uses safe commands (echo, true)
    local pipeline = {
        step("echo-start", "echo", { "Pipeline starting..." }),
        step("check-lua", "lua5.1", { "-e", "print('Lua OK')" }),
        step("list-modules", "ls", { "lib/safe/" }),
        step("echo-done", "echo", { "All steps complete." }),
    }

    -- Run in dry-run mode first to show the commands
    io.write("--- Dry Run ---\n")
    local _dry_ok, dry_results = run_pipeline(pipeline, true)
    print_summary(dry_results)

    -- Then run for real
    io.write("\n--- Live Run ---\n")
    local ok, results = run_pipeline(pipeline, false)
    print_summary(results)

    return ok and 0 or 1
end

os.exit(main(arg))
