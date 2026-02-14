#!/usr/bin/env lua5.1
--[[
  testing_patterns.lua — Example: mock factories, spies, and DI.
  Demonstrates test_helpers patterns: mock executors, mock popen,
  spy functions, dependency injection, and output capture.
  Patterns from resolve-pipeline: mock_resolve, make_exec_spy,
  swappable M._executor/M._popen.

  Usage: lua5.1 examples/testing_patterns.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local shell = require("safe.shell")
local log = require("safe.log")
local test_helpers = require("safe.test_helpers")

local string_format = string.format
local string_rep = string.rep
local tostring = tostring
local pcall = pcall

log.set_level(log.INFO)
log.set_context("testing")

-- ----------------------------------------------------------------
-- Pattern 1: Spy functions (capture calls for assertions)
-- ----------------------------------------------------------------

--- Create a spy function that records all calls.
--- @param return_value any value to return on each call
--- @return function spy, table records
local function make_spy(return_value)
    local records = {}
    local fn = function(...)
        records[#records + 1] = { ... }
        return return_value
    end
    return fn, records
end

-- ----------------------------------------------------------------
-- Pattern 2: Mock object factory (resolve-pipeline style)
-- ----------------------------------------------------------------

--- Create a mock "source" object with colon-syntax methods.
--- Mirrors resolve-pipeline's MockGalleryStill pattern.
--- @param label string source label
--- @return table mock source
local function MockSource(label)
    local source = {}
    local _label = label or "Untitled"
    local _active = true

    function source:GetLabel()
        return _label
    end

    function source:SetLabel(new_label)
        guard.assert_type(new_label, "string", "new_label")
        _label = new_label
        return true
    end

    function source:IsActive()
        return _active
    end

    function source:SetActive(active)
        _active = active
    end

    return source
end

-- ----------------------------------------------------------------
-- Pattern 3: Service with injectable dependencies
-- ----------------------------------------------------------------

--- A "service" that accepts deps for testability.
--- Mirrors resolve-pipeline's lib.run(state, deps) pattern.
--- @param deps table { executor, logger }
--- @return table results
local function run_service(deps)
    guard.assert_type(deps, "table", "deps")

    local executor = deps.executor or shell._executor
    local logger = deps.logger or log

    logger.info("service starting")

    local results = {}

    -- Execute some commands via injected executor
    local commands = {
        { name = "check", cmd = "echo 'checking...'" },
        { name = "build", cmd = "echo 'building...'" },
        { name = "test", cmd = "echo 'testing...'" },
    }

    for i = 1, #commands do
        logger.debug("running: %s", commands[i].name)
        local ok, _code = executor(commands[i].cmd)
        results[#results + 1] = {
            name = commands[i].name,
            ok = ok,
        }
    end

    logger.info("service complete: %d commands", #results)
    return results
end

local function main(_args)
    io.write("Testing Patterns\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- ----------------------------------------------------------------
    -- 1. Spy functions
    -- ----------------------------------------------------------------
    io.write("1. Spy Functions\n")
    io.write(string_rep("-", 50) .. "\n")

    local spy_fn, spy_calls = make_spy(42)

    spy_fn("hello", "world")
    spy_fn("foo")
    spy_fn()

    io.write(string_format("  calls made:    %d\n", #spy_calls))
    io.write(string_format("  call 1 args:   %s, %s\n", tostring(spy_calls[1][1]), tostring(spy_calls[1][2])))
    io.write(string_format("  call 2 args:   %s\n", tostring(spy_calls[2][1])))
    io.write(string_format("  call 3 args:   (none)\n"))
    guard.contract(#spy_calls == 3, "spy must record 3 calls")

    -- ----------------------------------------------------------------
    -- 2. Mock objects with colon syntax
    -- ----------------------------------------------------------------
    io.write("\n2. Mock Objects (colon syntax)\n")
    io.write(string_rep("-", 50) .. "\n")

    local source = MockSource("Webcam HD")
    io.write(string_format("  label:    %s\n", source:GetLabel()))
    io.write(string_format("  active:   %s\n", tostring(source:IsActive())))

    source:SetLabel("Front Camera")
    source:SetActive(false)
    io.write(string_format("  label:    %s (after SetLabel)\n", source:GetLabel()))
    io.write(string_format("  active:   %s (after SetActive)\n", tostring(source:IsActive())))

    -- Type contract on SetLabel
    local bad_ok = pcall(function()
        source:SetLabel(123)
    end)
    if bad_ok then
        io.write("  SetLabel(123): accepted (bad)\n")
    end
    if not bad_ok then
        io.write("  SetLabel(123): rejected (good)\n")
    end

    -- ----------------------------------------------------------------
    -- 3. Mock executor (test_helpers pattern)
    -- ----------------------------------------------------------------
    io.write("\n3. Mock Executor (test_helpers)\n")
    io.write(string_rep("-", 50) .. "\n")

    local mock_exec, exec_calls = test_helpers.mock_executor({
        { true, 0 },
        { true, 0 },
        { false, 1 },
    })

    -- Save original executor, inject mock
    local orig_executor = shell._executor
    shell._executor = mock_exec

    local ok1, _code1 = shell.exec("echo", { "hello" })
    local ok2, _code2 = shell.exec("make", { "test" })
    local ok3, _code3 = shell.exec("failing-cmd", {})

    io.write(string_format("  exec 1: %s (expected true)\n", tostring(ok1)))
    io.write(string_format("  exec 2: %s (expected true)\n", tostring(ok2)))
    io.write(string_format("  exec 3: %s (expected false)\n", tostring(ok3)))
    io.write(string_format("  commands captured: %d\n", #exec_calls))
    for i = 1, #exec_calls do
        io.write(string_format("    [%d] %s\n", i, exec_calls[i]))
    end

    -- Restore original executor
    shell._executor = orig_executor

    -- ----------------------------------------------------------------
    -- 4. Mock popen (capture output)
    -- ----------------------------------------------------------------
    io.write("\n4. Mock Popen (test_helpers)\n")
    io.write(string_rep("-", 50) .. "\n")

    local mock_popen, _popen_calls = test_helpers.mock_popen({
        { true, "file1.lua\nfile2.lua\n" },
        { false, nil },
    })

    local orig_popen = shell._popen
    shell._popen = mock_popen

    local cap_ok, cap_out = shell.capture("ls", { "lib/" })
    io.write(string_format("  capture 1 ok:     %s\n", tostring(cap_ok)))
    io.write(string_format("  capture 1 output: %s", tostring(cap_out)))

    local cap2_ok, cap2_out = shell.capture("failing", {})
    io.write(string_format("  capture 2 ok:     %s\n", tostring(cap2_ok)))
    io.write(string_format("  capture 2 output: %s\n", tostring(cap2_out)))

    shell._popen = orig_popen

    -- ----------------------------------------------------------------
    -- 5. Dependency injection (service pattern)
    -- ----------------------------------------------------------------
    io.write("\n5. Dependency Injection\n")
    io.write(string_rep("-", 50) .. "\n")

    local di_exec, di_calls = make_spy(true)
    local log_msgs = {}
    local mock_logger = {
        info = function(fmt, ...)
            log_msgs[#log_msgs + 1] = string_format(fmt, ...)
        end,
        debug = function(fmt, ...)
            log_msgs[#log_msgs + 1] = string_format(fmt, ...)
        end,
    }

    local results = run_service({
        executor = di_exec,
        logger = mock_logger,
    })

    io.write(string_format("  commands run:  %d\n", #results))
    io.write(string_format("  executor calls: %d\n", #di_calls))
    io.write(string_format("  log messages:  %d\n", #log_msgs))
    for i = 1, #results do
        io.write(string_format("    [%s] %s\n", results[i].ok and "OK" or "FAIL", results[i].name))
    end

    -- ----------------------------------------------------------------
    -- 6. Output capture (test_helpers)
    -- ----------------------------------------------------------------
    io.write("\n6. Output Capture (test_helpers)\n")
    io.write(string_rep("-", 50) .. "\n")

    local captured = test_helpers.capture_output(function()
        io.write("captured line 1\n")
        io.write("captured line 2\n")
    end)

    io.write(string_format("  captured %d bytes\n", #captured))
    io.write(string_format("  content: %q\n", captured))

    io.write("\n")
    log.info("testing patterns demo complete")
    return 0
end

os.exit(main(arg))
