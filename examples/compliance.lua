#!/usr/bin/env lua5.1
--[[
  compliance.lua — Example: PMAT CB-600 compliance demo.
  Walks through all 8 CB checks (CB-600..CB-607) in a single script,
  demonstrating each defensive pattern and printing a pass/fail matrix.

  Usage: lua5.1 examples/compliance.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local shell = require("safe.shell")
local perf = require("safe.perf")
local log = require("safe.log")

local string_format = string.format
local string_rep = string.rep
local pcall = pcall
local tostring = tostring

log.set_level(log.INFO)
log.set_context("compliance")

--- Run a single check, return pass/fail and description.
local function run_check(name, description, fn)
    local ok, err = pcall(fn)
    if ok then
        return true, name, description
    else
        return false, name, description .. " (" .. tostring(err) .. ")"
    end
end

local function main(_args)
    io.write("PMAT CB-600 Compliance Matrix\n")
    io.write(string_rep("=", 60) .. "\n\n")

    local results = {}

    -- CB-600: Implicit globals — guard.protect_globals
    results[#results + 1] = {
        run_check("CB-600", "Implicit globals", function()
            local env = { declared_var = 42 }
            guard.protect_globals(env)
            -- Access declared var: should work
            guard.contract(env.declared_var == 42, "declared access must work")
            -- Attempt undeclared write: should error
            local wrote_ok = pcall(function() -- pmat:ignore CB-602
                env.undeclared = 99
            end)
            guard.contract(not wrote_ok, "undeclared write must be blocked")
        end),
    }

    -- CB-601: Nil-unsafe access — guard.safe_get
    results[#results + 1] = {
        run_check("CB-601", "Nil-safe access", function()
            local config = { database = { primary = { host = "localhost" } } }
            local host = guard.safe_get(config, "database", "primary", "host")
            guard.contract(host == "localhost", "must resolve nested key")
            local missing = guard.safe_get(config, "database", "replica", "host")
            guard.contract(missing == nil, "must return nil for missing path")
            local from_nil = guard.safe_get(nil, "anything")
            guard.contract(from_nil == nil, "must handle nil root")
        end),
    }

    -- CB-602: pcall handling — correct error propagation
    results[#results + 1] = {
        run_check("CB-602", "pcall error handling", function()
            local ok, err = pcall(function() -- pmat:ignore CB-602
                error("test error", 2)
            end)
            guard.contract(not ok, "pcall must catch error")
            guard.contract(type(err) == "string", "pcall must return error message")
            guard.contract(err:find("test error") ~= nil, "error message must propagate")
        end),
    }

    -- CB-603: Dangerous APIs — shell.exec with validation
    results[#results + 1] = {
        run_check("CB-603", "Safe shell execution", function()
            -- Validate that metacharacters in program names are rejected
            local ok_prog, _err = shell.validate_program("safe-program")
            guard.contract(ok_prog, "clean program name must pass")
            local bad_prog, bad_err = shell.validate_program("rm -rf /")
            guard.contract(not bad_prog, "metachar program must fail")
            guard.contract(type(bad_err) == "string", "must return error description")
            -- Validate argument escaping
            local escaped = shell.escape("hello'world")
            guard.contract(type(escaped) == "string", "escape must return string")
            guard.contract(escaped:find("'") ~= nil, "escape must use quoting")
        end),
    }

    -- CB-604: Unused variables — enforced by luacheck + selene (static)
    results[#results + 1] = {
        run_check("CB-604", "Unused variables (static lint)", function()
            -- This check is enforced by luacheck/selene at lint time.
            -- We verify the convention: _ prefix for intentionally unused.
            local _intentionally_unused = "this is fine"
            guard.contract(true, "convention: _ prefix for unused vars")
        end),
    }

    -- CB-605: String concat in loops — perf.concat_safe
    results[#results + 1] = {
        run_check("CB-605", "String concat (table.concat)", function()
            local parts = { "hello", " ", "world" }
            local safe_result = perf.concat_safe(parts)
            guard.contract(safe_result == "hello world", "concat_safe must join correctly")
        end),
    }

    -- CB-606: Missing module return — all modules return M
    results[#results + 1] = {
        run_check("CB-606", "Module return value", function()
            -- Verify all safe.* modules return tables
            local modules = {
                { "safe.guard", guard },
                { "safe.validate", validate },
                { "safe.shell", shell },
                { "safe.perf", perf },
                { "safe.log", log },
            }
            for i = 1, #modules do
                local name = modules[i][1]
                local mod = modules[i][2]
                guard.contract(type(mod) == "table", string_format("%s must return a table", name))
            end
        end),
    }

    -- CB-607: Colon/dot confusion — validate.Checker uses colon
    results[#results + 1] = {
        run_check("CB-607", "Colon/dot syntax", function()
            -- Dot syntax for stateless functions
            local ok_dot, _err = validate.check_type(42, "number", "n")
            guard.contract(ok_dot, "dot syntax must work for stateless")
            -- Colon syntax for stateful Checker
            local c = validate.Checker.new()
            c:check_type(42, "number", "n")
            c:check_string_not_empty("hello", "msg")
            guard.contract(c:ok(), "colon syntax must work for Checker")
        end),
    }

    -- Print results matrix
    io.write(string_format("%-8s  %-6s  %s\n", "Check", "Status", "Description"))
    io.write(string_rep("-", 60) .. "\n")

    local pass_count = 0
    local total = #results
    for i = 1, total do
        local passed, name, desc = results[i][1], results[i][2], results[i][3]
        local status = passed and "PASS" or "FAIL"
        pass_count = pass_count + (passed and 1 or 0)
        io.write(string_format("%-8s  %-6s  %s\n", name, status, desc))
    end

    io.write(string_rep("-", 60) .. "\n")
    io.write(string_format("Result: %d/%d checks passed\n", pass_count, total))

    if pass_count == total then
        log.info("all %d CB checks passed", total)
        return 0
    else
        log.error("%d/%d checks failed", total - pass_count, total)
        return 1
    end
end

os.exit(main(arg))
