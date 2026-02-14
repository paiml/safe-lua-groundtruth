#!/usr/bin/env lua5.1
--[[
  global_protection.lua — Example: global protection and sandboxing.
  Demonstrates six patterns for protecting global state in Lua 5.1,
  drawn from lite-xl (strict mode), AwesomeWM (freeze), Kong (sandbox),
  and safe-lua (guard.protect_globals).

  Usage: lua5.1 examples/global_protection.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local log = require("safe.log")

local type = type
local pairs = pairs
local pcall = pcall
local rawset = rawset
local setmetatable = setmetatable
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local loadstring = loadstring
local string_format = string.format
local string_rep = string.rep
local string_sub = string.sub
local math_floor = math.floor
local math_ceil = math.ceil

log.set_level(log.INFO)
log.set_context("globals")

local function banner(title)
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("Pattern: %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- Pattern 1: Strict Mode (lite-xl pattern — gold standard)
--
-- A metatable on a sandboxed environment that errors on both
-- undeclared reads and writes.  A global() function whitelists
-- intentional declarations.
-- ================================================================

local function make_strict_env()
    local strict = {}
    strict.defined = {}

    local env = {}

    -- Register a variable as intentionally global
    local function declare_global(name)
        guard.assert_type(name, "string", "name")
        strict.defined[name] = true
    end

    setmetatable(env, {
        __newindex = function(_t, k, v)
            if not strict.defined[k] then
                error("cannot set undefined variable: " .. tostring(k), 2)
            end
            rawset(env, k, v)
        end,
        __index = function(_t, k)
            if not strict.defined[k] then
                error("cannot get undefined variable: " .. tostring(k), 2)
            end
            return nil
        end,
    })

    return env, declare_global
end

local function demo_strict_mode()
    banner("1. Strict Mode (lite-xl)")

    local env, declare_global = make_strict_env()

    -- Undeclared write: should error
    local ok_write, err_write = pcall(function()
        env.foo = 42
    end)
    io.write(string_format("  Undeclared write blocked: %s\n", tostring(not ok_write)))
    io.write(string_format("    Error: %s\n", tostring(err_write)))

    -- Undeclared read: should error
    local ok_read, err_read = pcall(function()
        local _unused = env.bar
    end)
    io.write(string_format("  Undeclared read blocked:  %s\n", tostring(not ok_read)))
    io.write(string_format("    Error: %s\n", tostring(err_read)))

    -- Intentional declaration via global()
    declare_global("counter")
    env.counter = 10
    io.write(string_format("  Declared global 'counter': %s\n", tostring(env.counter)))

    -- Verify declared read works
    declare_global("optional")
    local val = env.optional
    io.write(string_format("  Declared nil read 'optional': %s\n", tostring(val)))
end

-- ================================================================
-- Pattern 2: Freeze via __newindex = error (AwesomeWM pattern)
--
-- Sets __newindex to the error function directly.  Writes raise
-- an error, but reads of nonexistent keys silently return nil.
-- This is the DEFECTIVE pattern — it only protects one direction.
-- ================================================================

local function demo_write_only_freeze()
    banner("2. Write-only Freeze (AwesomeWM __newindex = error)")

    local frozen = setmetatable({ x = 1, y = 2 }, { __newindex = error })

    -- Write blocked
    local ok_write, _err_write = pcall(function()
        frozen.z = 3
    end)
    io.write(string_format("  Write blocked:  %s\n", tostring(not ok_write)))

    -- Read of existing key works
    io.write(string_format("  Read x:         %s\n", tostring(frozen.x)))

    -- Read of missing key returns nil (THE DEFECT)
    local missing = frozen.nonexistent
    io.write(string_format("  Read missing:   %s  (silent nil — defect!)\n", tostring(missing)))
end

-- ================================================================
-- Pattern 3: Complete Freeze (__index + __newindex)
--
-- The correct pattern: protect both directions.  Reads of unknown
-- keys error instead of silently returning nil.  Writes always
-- error.  This is what guard.freeze() does internally.
-- ================================================================

local function complete_freeze(tbl)
    local known = {}
    for k, _ in pairs(tbl) do
        known[k] = true
    end
    local proxy = {}
    setmetatable(proxy, {
        __index = function(_t, k)
            if not known[k] then
                error(string_format("read of unknown key: %s", tostring(k)), 2)
            end
            return tbl[k]
        end,
        __newindex = function(_t, k, _v)
            error(string_format("write to frozen key: %s", tostring(k)), 2)
        end,
    })
    return proxy
end

local function demo_complete_freeze()
    banner("3. Complete Freeze (__index + __newindex)")

    local frozen = complete_freeze({ x = 1, y = 2 })

    -- Read of existing key works
    io.write(string_format("  Read x:          %s\n", tostring(frozen.x)))

    -- Write blocked
    local ok_write, err_write = pcall(function()
        frozen.x = 99
    end)
    io.write(string_format("  Write blocked:   %s\n", tostring(not ok_write)))
    io.write(string_format("    Error: %s\n", tostring(err_write)))

    -- Read of missing key now errors (the fix)
    local ok_read, err_read = pcall(function()
        local _unused = frozen.nonexistent
    end)
    io.write(string_format("  Unknown read blocked: %s\n", tostring(not ok_read)))
    io.write(string_format("    Error: %s\n", tostring(err_read)))
end

-- ================================================================
-- Pattern 4: Sandbox Environment (Kong pattern)
--
-- A whitelist-based sandbox that only exposes safe functions.
-- Dangerous APIs (os.execute, io.popen, loadstring, require) are
-- not present.  Code loaded via loadstring runs in the sandbox.
-- ================================================================

local function make_sandbox()
    local sandbox = {
        pairs = pairs,
        ipairs = ipairs,
        type = type,
        tostring = tostring,
        tonumber = tonumber,
        string = { format = string_format, sub = string_sub },
        math = { floor = math_floor, ceil = math_ceil },
        -- Deliberately excluded: os.execute, io.popen, loadstring, require
    }
    return sandbox
end

local function run_in_sandbox(code, sandbox)
    guard.assert_type(code, "string", "code")
    guard.assert_type(sandbox, "table", "sandbox")

    local fn, compile_err = loadstring(code)
    if not fn then
        return false, "compile error: " .. tostring(compile_err)
    end
    setfenv(fn, sandbox) -- luacheck: ignore 113
    return pcall(fn)
end

local function demo_sandbox()
    banner("4. Sandbox Environment (Kong)")

    local sandbox = make_sandbox()

    -- Safe code: uses allowed functions
    local safe_code = [[
        local x = tonumber("42")
        local s = string.format("answer = %d", math.floor(x + 0.7))
        return s
    ]]
    local ok, result = run_in_sandbox(safe_code, sandbox)
    io.write(string_format("  Safe code OK:       %s\n", tostring(ok)))
    io.write(string_format("  Result:             %s\n", tostring(result)))

    -- Dangerous code: tries os.execute
    local danger_code = [[
        os.execute("echo pwned")
        return "escaped"
    ]]
    local ok_danger, err_danger = run_in_sandbox(danger_code, sandbox)
    io.write(string_format("  Dangerous code OK:  %s\n", tostring(ok_danger)))
    io.write(string_format("    Error: %s\n", tostring(err_danger)))

    -- Dangerous code: tries require
    local require_code = [[
        local m = require("os")
        return m
    ]]
    local ok_req, err_req = run_in_sandbox(require_code, sandbox)
    io.write(string_format("  require() blocked:  %s\n", tostring(not ok_req)))
    io.write(string_format("    Error: %s\n", tostring(err_req)))
end

-- ================================================================
-- Pattern 5: guard.protect_globals integration
--
-- safe-lua's own guard.protect_globals() installs a metatable on
-- any environment table that errors on undeclared access.  Unlike
-- the strict-mode pattern, it snapshots all existing keys at
-- protection time, so pre-existing globals remain accessible.
-- ================================================================

local function demo_protect_globals()
    banner("5. guard.protect_globals (safe-lua)")

    -- Create a test environment with some pre-existing globals
    local env = {
        config_mode = "production",
        max_retries = 3,
        debug_flag = false,
    }

    guard.protect_globals(env)

    -- Pre-existing globals still accessible
    io.write(string_format("  config_mode:  %s\n", tostring(env.config_mode)))
    io.write(string_format("  max_retries:  %s\n", tostring(env.max_retries)))

    -- Undeclared write blocked
    local ok_write, err_write = pcall(function()
        env.new_thing = "oops"
    end)
    io.write(string_format("  Undeclared write blocked: %s\n", tostring(not ok_write)))
    io.write(string_format("    Error: %s\n", tostring(err_write)))

    -- Undeclared read blocked
    local ok_read, err_read = pcall(function()
        local _unused = env.nonexistent
    end)
    io.write(string_format("  Undeclared read blocked:  %s\n", tostring(not ok_read)))
    io.write(string_format("    Error: %s\n", tostring(err_read)))

    -- Overwrite of declared key works (rawset under the hood)
    env.max_retries = 5
    io.write(string_format("  Updated max_retries:  %s\n", tostring(env.max_retries)))
end

-- ================================================================
-- Pattern 6: Read-only Configuration Table
--
-- Practical pattern: freeze a validated config table using
-- guard.freeze() so downstream code cannot accidentally mutate it.
-- ================================================================

local function demo_readonly_config()
    banner("6. Read-only Configuration Table")

    local raw_config = {
        host = "api.example.com",
        port = 443,
        timeout_ms = 5000,
        tls_enabled = true,
    }

    -- Freeze it
    local config = guard.freeze(raw_config)

    -- Reads work fine
    io.write(string_format("  host:        %s\n", tostring(config.host)))
    io.write(string_format("  port:        %s\n", tostring(config.port)))
    io.write(string_format("  timeout_ms:  %s\n", tostring(config.timeout_ms)))
    io.write(string_format("  tls_enabled: %s\n", tostring(config.tls_enabled)))

    -- Write attempt is blocked
    local ok_write, err_write = pcall(function()
        config.port = 80
    end)
    io.write(string_format("  Write blocked:    %s\n", tostring(not ok_write)))
    io.write(string_format("    Error: %s\n", tostring(err_write)))

    -- Can still read the original value
    io.write(string_format("  Port unchanged:   %s\n", tostring(config.port)))
end

-- ================================================================
-- Summary Matrix
-- ================================================================

local function print_summary()
    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("Protection Summary Matrix\n")
    io.write(string_rep("=", 60) .. "\n\n")

    local header = string_format("%-35s  %-7s  %-7s  %s\n", "Pattern", "Reads", "Writes", "Source")
    io.write(header)
    io.write(string_rep("-", 60) .. "\n")

    local patterns = {
        { "1. Strict mode (lite-xl)", "BLOCKS", "BLOCKS", "lite-xl" },
        { "2. __newindex = error (AwesomeWM)", "nil", "BLOCKS", "awesome" },
        { "3. Complete freeze (__index+__ni)", "BLOCKS", "BLOCKS", "manual" },
        { "4. Sandbox whitelist (Kong)", "BLOCKS", "BLOCKS", "kong" },
        { "5. guard.protect_globals", "BLOCKS", "BLOCKS", "safe-lua" },
        { "6. guard.freeze (read-only)", "ALLOWS", "BLOCKS", "safe-lua" },
    }

    for i = 1, #patterns do
        local p = patterns[i]
        io.write(string_format("%-35s  %-7s  %-7s  %s\n", p[1], p[2], p[3], p[4]))
    end

    io.write(string_rep("-", 60) .. "\n")
    io.write("\nBLOCKS = errors on access\n")
    io.write("ALLOWS = returns value (or nil for missing keys)\n")
    io.write("nil    = silently returns nil (defect)\n")
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("Global Protection & Sandboxing Patterns\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Six patterns from lite-xl, AwesomeWM, Kong, and safe-lua.\n")

    demo_strict_mode()
    demo_write_only_freeze()
    demo_complete_freeze()
    demo_sandbox()
    demo_protect_globals()
    demo_readonly_config()
    print_summary()

    io.write("\n")
    log.info("all six global protection patterns demonstrated")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
