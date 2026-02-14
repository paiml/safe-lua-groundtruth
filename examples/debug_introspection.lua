#!/usr/bin/env lua5.1
--[[
  debug_introspection.lua — Example: debug library introspection patterns.
  Demonstrates caller info extraction, traceback formatting, deprecation
  warnings (AwesomeWM gears.debug), function metadata, stack depth
  measurement, and safe stringification (APISIX inspect/dbg.lua).

  Usage: lua5.1 examples/debug_introspection.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local type = type
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring
local string_format = string.format
local string_rep = string.rep
local string_match = string.match
local string_find = string.find
local debug_getinfo = debug.getinfo
local debug_traceback = debug.traceback
local io_write = io.write

log.set_level(log.INFO)
log.set_context("debug-intro")

local function banner(title)
    io_write("\n" .. string_rep("=", 60) .. "\n")
    io_write("  " .. title .. "\n")
    io_write(string_rep("=", 60) .. "\n\n")
end

local function section(title)
    io_write("--- " .. title .. " ---\n")
end

-- Pattern 1: Caller Info — debug.getinfo(level, "Sl") for source location

local function caller_info(level)
    guard.assert_type(level, "number", "level")
    guard.contract(level >= 1, "level must be >= 1")
    local info = debug_getinfo(level, "Sl")
    if not info then
        return nil
    end
    return { source = info.source, line = info.currentline, short_src = info.short_src }
end

-- Pattern 2: Clean Traceback Formatter — strips "stack traceback:" prefix

local function format_traceback(msg, level)
    if msg ~= nil then
        local ok_type, _ = validate.check_type(msg, "string", "msg")
        if not ok_type then
            msg = tostring(msg)
        end
    else
        msg = ""
    end
    level = level or 2
    guard.assert_type(level, "number", "level")
    local raw = debug_traceback(msg, level)
    if not raw then
        return msg
    end
    local prefix = "stack traceback:\n"
    local pos = string_find(raw, prefix, 1, true)
    if pos then
        return raw:sub(1, pos - 1) .. raw:sub(pos + #prefix)
    end
    return raw
end

-- Pattern 3: Deprecation Warning (AwesomeWM gears.debug) — once per call site

local function make_deprecation_warner()
    local seen = {}
    return function(old_name, new_name, level)
        guard.assert_type(old_name, "string", "old_name")
        guard.assert_type(new_name, "string", "new_name")
        level = level or 2
        guard.assert_type(level, "number", "level")
        local info = debug_getinfo(level, "Sl")
        if not info then
            log.warn("%s is deprecated, use %s instead", old_name, new_name)
            return
        end
        local site = string_format("%s:%d", info.source or "?", info.currentline or 0)
        if seen[site] then
            return
        end
        seen[site] = true
        log.warn("%s is deprecated, use %s instead (at %s)", old_name, new_name, site)
    end
end

-- Pattern 4: Function Metadata — debug.getinfo(fn, "Slu") for reflection

local function function_info(fn)
    guard.assert_type(fn, "function", "fn")
    local info = debug_getinfo(fn, "Slu")
    return {
        source = info.source,
        short_src = info.short_src,
        linedefined = info.linedefined,
        lastlinedefined = info.lastlinedefined,
        nups = info.nups,
        what = info.what,
    }
end

-- Pattern 5: Stack Depth — iterate debug.getinfo(i, "") until nil

local function stack_depth()
    local depth = 0
    local i = 1
    while debug_getinfo(i, "") do
        depth = depth + 1
        i = i + 1
    end
    return depth
end

-- Pattern 6: Safe Tostring — pcall(tostring) with fallback for broken __tostring

local function safe_tostring(value)
    local t = type(value)
    if t ~= "table" and t ~= "userdata" then
        return tostring(value)
    end
    local ok, result = pcall(tostring, value)
    if ok then
        return result
    end
    local mt = nil
    if t == "table" then
        mt = getmetatable(value)
        setmetatable(value, nil)
    end
    local raw = tostring(value)
    if mt then
        setmetatable(value, mt)
    end
    return string_format("<%s %s (__tostring error)>", t, string_match(raw, "0x%x+") or "?")
end

-- Demo functions

local function demo_caller_info()
    banner("Pattern 1: Caller Info (debug.getinfo)")
    local info = caller_info(2)
    if info then
        io_write(string_format("  source: %s  line: %d\n", tostring(info.short_src), info.line))
    end
    for level = 1, 4 do
        local lvl_info = caller_info(level)
        if lvl_info then
            io_write(string_format("  level %d: %s:%d\n", level, lvl_info.short_src, lvl_info.line))
        else
            io_write(string_format("  level %d: (none)\n", level))
        end
    end
    local ok, err = pcall(caller_info, "bad")
    io_write(string_format("\n  Type guard: ok=%s err=%s\n", tostring(ok), tostring(err)))
end

local function demo_traceback()
    banner("Pattern 2: Clean Traceback Formatter")
    local function inner_c()
        return format_traceback("error occurred here", 1)
    end
    local function inner_b()
        return inner_c()
    end
    local function inner_a()
        return inner_b()
    end
    section("Formatted traceback from nested calls")
    local tb = inner_a()
    io_write("  " .. tb:gsub("\n", "\n  ") .. "\n\n")
end

local function demo_deprecation_warning()
    banner("Pattern 3: Deprecation Warning (AwesomeWM gears.debug)")
    local deprecation_warning = make_deprecation_warner()
    -- level=3: 1=deprecation_warning, 2=old_api, 3=caller of old_api
    local function old_api()
        deprecation_warning("old_api", "new_api", 3)
        return "old result"
    end
    section("Three calls from same call site (warns once)")
    for i = 1, 3 do
        local result = old_api()
        io_write(string_format("  call %d: result=%s\n", i, result))
    end
    io_write("\n")
    section("Call from different call site (warns again)")
    local result2 = old_api()
    io_write(string_format("  result=%s\n\n", result2))
    local ok, err = pcall(deprecation_warning, 42, "new", 2)
    io_write(string_format("  Type guard: ok=%s err=%s\n", tostring(ok), tostring(err)))
end

local function demo_function_info()
    banner("Pattern 4: Function Metadata (debug.getinfo)")
    local fns = {
        { name = "demo_function_info", fn = demo_function_info },
        { name = "guard.assert_type", fn = guard.assert_type },
        { name = "log.info", fn = log.info },
        { name = "string.format", fn = string.format },
        { name = "pairs", fn = pairs },
        { name = "type", fn = type },
    }
    io_write(string_format("  %-25s %-6s %-6s %s\n", "Function", "What", "Ups", "Source"))
    io_write("  " .. string_rep("-", 55) .. "\n")
    for _, entry in pairs(fns) do
        local fi = function_info(entry.fn)
        io_write(string_format("  %-25s %-6s %-6d %s\n", entry.name, fi.what, fi.nups, fi.short_src))
    end
    local ok, err = pcall(function_info, "not a function")
    io_write(string_format("\n  Type guard: ok=%s err=%s\n", tostring(ok), tostring(err)))
end

local function demo_stack_depth()
    banner("Pattern 5: Stack Depth Measurement")
    io_write(string_format("  Current depth: %d\n\n", stack_depth()))
    local function recursive_depth(n, limit, results)
        guard.assert_type(n, "number", "n")
        guard.assert_type(results, "table", "results")
        results[#results + 1] = { level = n, depth = stack_depth() }
        if n < limit then
            recursive_depth(n + 1, limit, results)
        end
    end
    local results = {}
    recursive_depth(1, 5, results)
    for _, r in pairs(results) do
        io_write(string_format("  recursion level %d -> stack depth %d\n", r.level, r.depth))
    end
    if #results >= 2 then
        io_write(string_format("  Increment per level: %d\n", results[2].depth - results[1].depth))
    end
end

local function demo_safe_tostring()
    banner("Pattern 6: Safe Tostring (APISIX inspect/dbg.lua)")
    local values = {
        { "number", 42 },
        { "string", "hello" },
        { "boolean", true },
        { "nil", nil },
        { "plain table", { 1, 2, 3 } },
    }
    for _, v in pairs(values) do
        io_write(string_format("  %-14s -> %s\n", v[1], safe_tostring(v[2])))
    end

    local good = setmetatable({}, {
        __tostring = function()
            return "MyObject{ok}"
        end,
    })
    io_write(string_format("\n  good __tostring   -> %s\n", safe_tostring(good)))

    local bad = setmetatable({}, {
        __tostring = function()
            error("exploded!")
        end,
    })
    io_write(string_format("  broken __tostring -> %s\n", safe_tostring(bad)))

    local weird = setmetatable({}, {
        __tostring = function()
            return 12345
        end,
    })
    io_write(string_format("  non-string return -> %s\n", safe_tostring(weird)))
    io_write(string_format("  function value    -> %s\n", safe_tostring(demo_safe_tostring)))
end

-- Summary

local function print_summary()
    io_write("\n" .. string_rep("=", 60) .. "\n")
    io_write("Debug Introspection Summary\n")
    io_write(string_rep("=", 60) .. "\n\n")
    io_write(string_format("%-5s %-30s %s\n", "#", "Pattern", "Source"))
    io_write(string_rep("-", 60) .. "\n")
    local patterns = {
        { "1", "Caller info (getinfo)", "logging / error reporters" },
        { "2", "Clean traceback formatter", "debug.traceback wrapper" },
        { "3", "Deprecation warning (once)", "AwesomeWM gears.debug" },
        { "4", "Function metadata", "APISIX inspect/dbg.lua" },
        { "5", "Stack depth measurement", "recursion limiting" },
        { "6", "Safe tostring", "APISIX inspect/dbg.lua" },
    }
    for _, p in pairs(patterns) do
        io_write(string_format("%-5s %-30s %s\n", p[1], p[2], p[3]))
    end
    io_write(string_rep("-", 60) .. "\n")
end

-- Main

local function main(_args)
    io_write("Debug Library Introspection Patterns\n")
    io_write(string_rep("=", 60) .. "\n")
    io_write("Six patterns from AwesomeWM, APISIX, and defensive Lua.\n")

    demo_caller_info()
    demo_traceback()
    demo_deprecation_warning()
    demo_function_info()
    demo_stack_depth()
    demo_safe_tostring()
    print_summary()

    io_write("\n")
    log.info("all six debug introspection patterns demonstrated")
    io_write("Done.\n")
    return 0
end

os.exit(main(arg))
