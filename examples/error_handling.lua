#!/usr/bin/env lua5.1
--[[
  error_handling.lua — Example: error handling patterns from top Lua projects.
  Demonstrates nil-err returns, pcall, xpcall, error levels, assert vs error,
  safe concatenation, silent failure detection, and three-value pcall unpacking.

  Usage: lua5.1 examples/error_handling.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local pcall = pcall
local xpcall = xpcall
local error = error
local tostring = tostring
local type = type
local string_format = string.format
local string_rep = string.rep
local io_write = io.write
local io_open = io.open
local debug_traceback = debug.traceback

log.set_level(log.INFO)
log.set_context("error_handling")

-- ----------------------------------------------------------------
-- Results matrix: tracks pass/fail for each pattern demo
-- ----------------------------------------------------------------
local results = {}

local function record(name, passed)
    results[#results + 1] = { name = name, passed = passed }
end

local function print_matrix()
    io_write("\n" .. string_rep("=", 60) .. "\n")
    io_write("Results Matrix\n")
    io_write(string_rep("=", 60) .. "\n")
    io_write(string_format("  %-45s %s\n", "Pattern", "Status"))
    io_write(string_rep("-", 60) .. "\n")
    local all_pass = true
    for i = 1, #results do
        local r = results[i]
        local status = r.passed and "PASS" or "FAIL"
        if not r.passed then
            all_pass = false
        end
        io_write(string_format("  %-45s [%s]\n", r.name, status))
    end
    io_write(string_rep("-", 60) .. "\n")
    io_write(string_format("  %d/%d passed\n", #results, #results))
    if not all_pass then
        io_write("  (some patterns failed)\n")
    end
end

-- ----------------------------------------------------------------
-- Pattern 1: return nil, err (Kong, APISIX, xmake)
-- ----------------------------------------------------------------
local function parse_port(input)
    local ok, err = validate.check_type(input, "string", "input")
    if not ok then
        return nil, "parse_port: " .. tostring(err)
    end
    local n = tonumber(input)
    if not n then
        return nil, "parse_port: not a number: " .. input
    end
    local range_ok, range_err = validate.check_range(n, 1, 65535, "port")
    if not range_ok then
        return nil, "parse_port: " .. tostring(range_err)
    end
    return n, nil
end

local function demo_nil_err()
    io_write("1. return nil, err (Kong, APISIX, xmake)\n")
    io_write(string_rep("-", 60) .. "\n")

    -- Success case
    local port, err = parse_port("8080")
    io_write(string_format("  parse_port('8080'): port=%s err=%s\n", tostring(port), tostring(err)))
    guard.contract(port == 8080, "expected 8080")

    -- Failure: out of range
    local port2, err2 = parse_port("99999")
    io_write(string_format("  parse_port('99999'): port=%s err=%s\n", tostring(port2), tostring(err2)))
    guard.contract(port2 == nil, "expected nil")

    -- Failure: wrong type
    local port3, err3 = parse_port(42)
    io_write(string_format("  parse_port(42):      port=%s err=%s\n", tostring(port3), tostring(err3)))
    guard.contract(port3 == nil, "expected nil")

    -- Chain context: caller wraps the error
    local function connect(host, port_str)
        local p, perr = parse_port(port_str)
        if not p then
            return nil, "connect: " .. tostring(perr)
        end
        return string_format("%s:%d", host, p), nil
    end

    local addr, cerr = connect("localhost", "abc")
    io_write(string_format("  connect('localhost','abc'): %s\n", tostring(cerr)))
    guard.contract(addr == nil, "expected nil")
    io_write("\n")

    record("1. return nil, err", true)
end

-- ----------------------------------------------------------------
-- Pattern 2: pcall wrapping (universal)
-- ----------------------------------------------------------------
local function risky_decode(input)
    guard.assert_type(input, "string", "input")
    if input == "" then
        error("empty input")
    end
    return "decoded:" .. input
end

local function demo_pcall()
    io_write("2. pcall wrapping (universal)\n")
    io_write(string_rep("-", 60) .. "\n")

    -- Success
    local ok, result = pcall(risky_decode, "hello")
    io_write(string_format("  pcall(decode, 'hello'): ok=%s result=%s\n", tostring(ok), tostring(result)))
    guard.contract(ok, "expected success")

    -- Failure: throws error
    local ok2, err2 = pcall(risky_decode, "")
    io_write(string_format("  pcall(decode, ''):      ok=%s err=%s\n", tostring(ok2), tostring(err2)))
    guard.contract(not ok2, "expected failure")

    -- Failure: type error from guard
    local ok3, err3 = pcall(risky_decode, 42)
    io_write(string_format("  pcall(decode, 42):      ok=%s err=%s\n", tostring(ok3), tostring(err3)))
    guard.contract(not ok3, "expected failure")
    io_write("\n")

    record("2. pcall wrapping", true)
end

-- ----------------------------------------------------------------
-- Pattern 3: xpcall with error handler (AwesomeWM, LOVE, lazy.nvim)
-- ----------------------------------------------------------------
local function demo_xpcall()
    io_write("3. xpcall with error handler (AwesomeWM, LOVE)\n")
    io_write(string_rep("-", 60) .. "\n")

    local captured_tb = nil

    local function error_handler(err)
        captured_tb = tostring(err) .. "\n" .. debug_traceback("", 2)
        return err
    end

    local function deep_call()
        error("something broke in deep_call")
    end

    local function middle_call()
        deep_call()
    end

    local ok, err = xpcall(middle_call, error_handler)
    io_write(string_format("  xpcall ok:     %s\n", tostring(ok)))
    io_write(string_format("  error:         %s\n", tostring(err)))
    guard.contract(not ok, "expected failure")
    guard.contract(captured_tb ~= nil, "expected traceback")

    -- Show first two lines of traceback
    local lines = {}
    for line in captured_tb:gmatch("[^\n]+") do
        lines[#lines + 1] = line
        if #lines >= 3 then
            break
        end
    end
    io_write("  traceback (first 3 lines):\n")
    for i = 1, #lines do
        io_write("    " .. lines[i] .. "\n")
    end
    io_write("\n")

    record("3. xpcall with traceback", true)
end

-- ----------------------------------------------------------------
-- Pattern 4: error(msg, level) with stack levels (Kong)
-- ----------------------------------------------------------------
local function demo_error_levels()
    io_write("4. error(msg, level) with stack levels (Kong)\n")
    io_write(string_rep("-", 60) .. "\n")

    -- Level 1: error points at the function that called error()
    local function bad_api_level1(x)
        if type(x) ~= "string" then
            error("bad_api: expected string, got " .. type(x), 1)
        end
    end

    -- Level 2: error points at the caller of the function (preferred for APIs)
    local function bad_api_level2(x)
        if type(x) ~= "string" then
            error("bad_api: expected string, got " .. type(x), 2)
        end
    end

    local ok1, err1 = pcall(bad_api_level1, 42)
    io_write(string_format("  level 1 error: %s\n", tostring(err1)))
    guard.contract(not ok1, "expected error")

    local ok2, err2 = pcall(bad_api_level2, 42)
    io_write(string_format("  level 2 error: %s\n", tostring(err2)))
    guard.contract(not ok2, "expected error")

    -- guard.assert_type uses level 2 by default
    local ok3, err3 = pcall(guard.assert_type, nil, "table", "config")
    io_write(string_format("  guard.assert_type: %s\n", tostring(err3)))
    guard.contract(not ok3, "expected error")
    io_write("\n")

    record("4. error(msg, level)", true)
end

-- ----------------------------------------------------------------
-- Pattern 5: assert() vs error() — library vs test context
-- ----------------------------------------------------------------
local function demo_assert_vs_error()
    io_write("5. assert() vs error() — library vs test\n")
    io_write(string_rep("-", 60) .. "\n")

    -- assert() is fine in tests — test runners catch it
    io_write("  In tests: assert(value == expected) is idiomatic\n")

    -- In library code, error(msg, 2) gives the caller the right location
    local function lib_set_timeout(seconds)
        if type(seconds) ~= "number" or seconds <= 0 then
            error("set_timeout: seconds must be positive number", 2)
        end
        return seconds
    end

    -- Library error points to caller
    local ok, err = pcall(lib_set_timeout, -1)
    io_write(string_format("  lib error(msg, 2): %s\n", tostring(err)))
    guard.contract(not ok, "expected error")

    -- guard.contract works like assert() with configurable level
    local ok2, err2 = pcall(guard.contract, false, "contract violated")
    io_write(string_format("  guard.contract:    %s\n", tostring(err2)))
    guard.contract(not ok2, "expected error")

    io_write("  Recommendation: error(msg, 2) in libraries,\n")
    io_write("                  assert() in tests\n\n")

    record("5. assert() vs error()", true)
end

-- ----------------------------------------------------------------
-- Pattern 6: Error concatenation safety
-- ----------------------------------------------------------------
local function demo_concat_safety()
    io_write("6. Error concatenation safety\n")
    io_write(string_rep("-", 60) .. "\n")

    -- The bug: concatenating a nil error value crashes
    local function unsafe_open(path)
        local _f, err = io_open(path, "r")
        -- Intentionally return nil to simulate a nil err
        return nil, err
    end

    local _, raw_err = unsafe_open("/nonexistent/path")
    io_write(string_format("  raw error type: %s\n", type(raw_err)))

    -- Dangerous pattern: "prefix: " .. err crashes if err is nil
    local crash_ok, crash_err = pcall(function()
        local _, _e = unsafe_open("/nonexistent/path")
        -- This would crash if e were nil:
        -- return "failed: " .. e
        -- Simulate the nil case:
        local nil_err = nil
        return "failed: " .. nil_err
    end)
    io_write(string_format("  concat nil crashes: %s (%s)\n", tostring(not crash_ok), tostring(crash_err)))

    -- Safe pattern: always use tostring()
    local function safe_open(path)
        local f, err = io_open(path, "r")
        if not f then
            return nil, "open failed: " .. tostring(err)
        end
        f:close()
        return true, nil
    end

    local _, safe_err = safe_open("/nonexistent/path")
    io_write(string_format("  safe tostring():    %s\n", tostring(safe_err)))

    -- Even safer: string.format with %s handles nil
    local function safest_open(path)
        local f, err = io_open(path, "r")
        if not f then
            return nil, string_format("open failed: %s", tostring(err))
        end
        f:close()
        return true, nil
    end

    local _, safest_err = safest_open("/nonexistent/path")
    io_write(string_format("  string.format:      %s\n", tostring(safest_err)))
    io_write("\n")

    record("6. Concatenation safety", true)
end

-- ----------------------------------------------------------------
-- Pattern 7: Silent failure anti-pattern
-- ----------------------------------------------------------------
local function demo_silent_failure()
    io_write("7. Silent failure anti-pattern\n")
    io_write(string_rep("-", 60) .. "\n")

    -- DEFECT: no check on io.open return value
    io_write("  Defect (unchecked io.open):\n")
    io_write("    local f = io.open(path)\n")
    io_write("    f:read('*a')  -- crashes if path missing!\n\n")

    local defect_ok, defect_err = pcall(function()
        local f = io_open("/nonexistent/file.txt")
        return f:read("*a")
    end)
    io_write(string_format("  unchecked crash: ok=%s err=%s\n", tostring(defect_ok), tostring(defect_err)))

    -- CORRECT: always check the return value
    io_write("\n  Correct pattern:\n")
    local function safe_read(path)
        local ok, perr = validate.check_string_not_empty(path, "path")
        if not ok then
            return nil, perr
        end
        local f, err = io_open(path, "r")
        if not f then
            return nil, "cannot open: " .. tostring(err)
        end
        local content = f:read("*a")
        f:close()
        return content, nil
    end

    local content, err = safe_read("/nonexistent/file.txt")
    io_write(string_format("  safe_read: content=%s err=%s\n", tostring(content), tostring(err)))
    guard.contract(content == nil, "expected nil")

    local content2, err2 = safe_read("")
    io_write(string_format("  safe_read(''): content=%s err=%s\n", tostring(content2), tostring(err2)))
    guard.contract(content2 == nil, "expected nil")
    io_write("\n")

    record("7. Silent failure detection", true)
end

-- ----------------------------------------------------------------
-- Pattern 8: Three-value pcall unpacking (Kong pattern)
-- ----------------------------------------------------------------
local function demo_three_value_pcall()
    io_write("8. Three-value pcall unpacking (Kong)\n")
    io_write(string_rep("-", 60) .. "\n")

    -- A function that returns ok, err (like Kong's DB operations)
    local function db_query(sql)
        local ok, verr = validate.check_string_not_empty(sql, "sql")
        if not ok then
            return nil, verr
        end
        if sql:find("DROP") then
            return nil, "forbidden: DROP not allowed"
        end
        return { rows = 3, sql = sql }, nil
    end

    -- The Kong pattern: pcall wraps a function that itself returns ok, err.
    -- pcall adds its own ok/err layer, so you get three values.
    io_write("  Standard two-layer unwrap:\n")

    local pok, result_or_err, inner_err = pcall(db_query, "SELECT 1")
    if not pok then
        -- pcall itself failed (runtime error)
        io_write(string_format("    runtime error: %s\n", tostring(result_or_err)))
    elseif not result_or_err then
        -- pcall succeeded but db_query returned nil, err
        io_write(string_format("    query error: %s\n", tostring(inner_err)))
    else
        -- Both layers succeeded
        io_write(string_format("    query ok: rows=%s\n", tostring(result_or_err.rows)))
    end

    -- Kong-style normalization: flatten to ok, err
    io_write("\n  Kong-style normalization:\n")

    local function safe_query(sql)
        local pok2, ok2, err2 = pcall(db_query, sql)
        if not pok2 then
            -- pcall itself threw: ok2 is actually the error message
            err2 = ok2
            ok2 = nil
        end
        return ok2, err2
    end

    local r1, _e1 = safe_query("SELECT 1")
    io_write(string_format("    safe_query('SELECT 1'): ok=%s\n", tostring(r1 ~= nil)))
    guard.contract(r1 ~= nil, "expected result")

    local r2, e2 = safe_query("DROP TABLE users")
    io_write(string_format("    safe_query('DROP...'): err=%s\n", tostring(e2)))
    guard.contract(r2 == nil, "expected nil")

    local r3, e3 = safe_query("")
    io_write(string_format("    safe_query(''):        err=%s\n", tostring(e3)))
    guard.contract(r3 == nil, "expected nil")
    io_write("\n")

    record("8. Three-value pcall unpacking", true)
end

-- ----------------------------------------------------------------
-- Main
-- ----------------------------------------------------------------
local function main(_args)
    io_write("Error Handling Patterns (from top Lua projects)\n")
    io_write(string_rep("=", 60) .. "\n\n")

    demo_nil_err()
    demo_pcall()
    demo_xpcall()
    demo_error_levels()
    demo_assert_vs_error()
    demo_concat_safety()
    demo_silent_failure()
    demo_three_value_pcall()

    print_matrix()

    io_write("\n")
    log.info("error handling demo complete")
    return 0
end

os.exit(main(arg))
