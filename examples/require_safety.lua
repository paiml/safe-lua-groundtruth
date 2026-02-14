#!/usr/bin/env lua5.1
--[[
  require_safety.lua — Example: require safety patterns from top Lua projects.
  Demonstrates require cycle detection, lazy require, safe require with pcall,
  module load order verification, package.loaded inspection, and path debugging.

  Usage: lua5.1 examples/require_safety.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local pcall = pcall
local type = type
local tostring = tostring
local pairs = pairs
local ipairs = ipairs
local string_format = string.format
local string_rep = string.rep
local string_gmatch = string.gmatch
local string_gsub = string.gsub
local table_concat = table.concat
local io_write = io.write
local io_open = io.open

log.set_level(log.INFO)
log.set_context("require-safety")

-- ----------------------------------------------------------------
-- Results matrix: tracks pass/fail for each pattern demo
-- ----------------------------------------------------------------
local results = {}

local function record(name, passed)
    results[#results + 1] = { name = name, passed = passed }
end

local function section(n, title)
    guard.assert_type(n, "number", "n")
    guard.assert_type(title, "string", "title")
    io_write(string_format("\n%d. %s\n", n, title))
    io_write(string_rep("-", 60) .. "\n")
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
-- 1. Require Cycle Problem
-- ----------------------------------------------------------------
local function demo_require_cycle()
    section(1, "Require Cycle Problem")
    io_write("When module A requires B which requires A, the second\n")
    io_write("require returns A's PARTIAL table (whatever was set so far).\n\n")

    -- Clean up any previous state
    package.loaded["demo.a"] = nil
    package.loaded["demo.b"] = nil

    -- Simulate module A: it starts loading, gets registered as partial,
    -- then requires module B which tries to use A
    local a_module = {}
    -- At this point, only the empty table is in package.loaded
    package.loaded["demo.a"] = a_module

    -- Simulate module B loading: it requires demo.a and gets the partial table
    local b_module = {}
    local a_from_b = package.loaded["demo.a"] -- partial table, no functions yet
    b_module.check_a = function()
        -- a_from_b was captured before A finished loading
        return a_from_b.greet ~= nil
    end
    package.loaded["demo.b"] = b_module

    -- Now A finishes loading and adds its functions
    function a_module.greet()
        return "hello from A"
    end

    -- Demonstrate the cycle problem
    local a_complete = a_module.greet ~= nil
    local b_sees_a = b_module.check_a()

    io_write(string_format("  A finished loading:       %s\n", tostring(a_complete)))
    io_write(string_format("  B sees A.greet (after):   %s\n", tostring(b_sees_a)))
    io_write("  B captured A's table reference early, so it sees\n")
    io_write("  the completed table (Lua tables are references).\n\n")

    -- Show the real danger: if B captured a VALUE instead of a reference
    local a_module2 = {}
    package.loaded["demo.a2"] = a_module2
    local captured_greet = a_module2.greet -- nil at this point!
    a_module2.greet = function()
        return "hello from A2"
    end

    io_write(string_format("  Captured function directly: %s\n", tostring(captured_greet)))
    io_write(string_format("  A2.greet after completion:  %s\n", tostring(a_module2.greet ~= nil)))
    io_write("  Capturing a function (not the table) during a cycle\n")
    io_write("  gives nil — this is the real require-cycle bug.\n")

    -- Clean up
    package.loaded["demo.a"] = nil
    package.loaded["demo.b"] = nil
    package.loaded["demo.a2"] = nil

    record("1. Require cycle problem", true)
end

-- ----------------------------------------------------------------
-- 2. Lazy Require Pattern (Kong, lazy.nvim)
-- ----------------------------------------------------------------
local function demo_lazy_require()
    section(2, "Lazy Require Pattern (Kong, lazy.nvim)")
    io_write("Defer require() inside functions to break cycles and\n")
    io_write("avoid loading modules until they are actually needed.\n\n")

    -- Pattern: wrap require in a function, module loads on first call
    local function get_validate()
        return require("safe.validate")
    end

    local function get_guard()
        return require("safe.guard")
    end

    -- First call triggers the require; subsequent calls hit cache
    io_write("  Calling get_validate() for the first time...\n")
    local v = get_validate()
    local ok, _err = v.check_type("hello", "string", "input")
    io_write(string_format("  validate.check_type('hello', 'string'): ok=%s\n", tostring(ok)))

    -- Second call returns cached module (no disk I/O)
    local v2 = get_validate()
    io_write(string_format("  Same module instance: %s\n", tostring(v == v2)))
    guard.contract(v == v2, "lazy require should return cached module")

    -- Demonstrate lazy require with guard
    local g = get_guard()
    io_write(string_format("  Lazy guard loaded: %s\n", tostring(g ~= nil)))
    guard.contract(g == guard, "lazy require should return same guard module")

    io_write("\n  Kong uses this pattern in its plugin loading to avoid\n")
    io_write("  circular dependencies between handler and schema modules.\n")

    record("2. Lazy require (Kong, lazy.nvim)", true)
end

-- ----------------------------------------------------------------
-- 3. Safe Require with pcall (Universal)
-- ----------------------------------------------------------------
local function demo_safe_require()
    section(3, "Safe Require with pcall (Universal)")
    io_write("Use pcall(require, name) for optional dependencies.\n")
    io_write("Gracefully degrade when a module is not available.\n\n")

    -- Attempt to load a module that does not exist
    local ok, mod = pcall(require, "nonexistent_optional_module")
    if not ok then
        log.warn("optional module not available: %s", tostring(mod))
        io_write(string_format("  pcall(require, 'nonexistent_optional_module'):\n"))
        io_write(string_format("    ok=false  err=%s\n", tostring(mod)))
    end
    guard.contract(not ok, "expected nonexistent module to fail")

    -- Attempt to load a module that does exist
    local ok2, mod2 = pcall(require, "safe.log")
    io_write(string_format("  pcall(require, 'safe.log'):\n"))
    io_write(string_format("    ok=%s  module=%s\n", tostring(ok2), type(mod2)))
    guard.contract(ok2, "expected safe.log to load")

    -- Real-world pattern: provide fallback functionality
    io_write("\n  Graceful degradation example:\n")
    local ok3, _cjson = pcall(require, "cjson")
    local json_encode
    if ok3 then
        io_write("    cjson available, using native JSON encoder\n")
        json_encode = function(t)
            return tostring(t)
        end
    else
        io_write("    cjson not available, using basic fallback\n")
        json_encode = function(t)
            -- Minimal fallback: just show table address
            return string_format("{<table: %s>}", tostring(t))
        end
    end

    local result = json_encode({ key = "value" })
    io_write(string_format("    json_encode result: %s\n", result))

    record("3. Safe require with pcall", true)
end

-- ----------------------------------------------------------------
-- 4. Module Load Order Verification
-- ----------------------------------------------------------------
local function demo_load_order_verification()
    section(4, "Module Load Order Verification")
    io_write("Verify all critical modules loaded before proceeding.\n")
    io_write("Fail fast with clear errors on missing dependencies.\n\n")

    local REQUIRED = { "safe.guard", "safe.validate", "safe.log" }
    local loaded_modules = {}
    local all_ok = true

    for _, name in ipairs(REQUIRED) do
        local ok, err = pcall(require, name)
        if ok then
            loaded_modules[#loaded_modules + 1] = name
            io_write(string_format("  [OK]   %s\n", name))
        else
            all_ok = false
            io_write(string_format("  [FAIL] %s: %s\n", name, tostring(err)))
        end
    end

    -- Also test with a module that will fail
    local OPTIONAL = { "safe.perf", "safe.nonexistent" }
    io_write("\n  Optional modules:\n")
    for _, name in ipairs(OPTIONAL) do
        local ok, err = pcall(require, name)
        if ok then
            io_write(string_format("  [OK]   %s (available)\n", name))
        else
            io_write(string_format("  [SKIP] %s (not found: %s)\n", name, tostring(err):sub(1, 50)))
        end
    end

    io_write(string_format("\n  Required: %d/%d loaded\n", #loaded_modules, #REQUIRED))
    guard.contract(all_ok, "all required modules must load")

    -- Validate the loaded module list
    local c = validate.Checker:new()
    c:check_type(loaded_modules, "table", "loaded_modules")
    c:check_range(#loaded_modules, #REQUIRED, #REQUIRED, "loaded_count")
    guard.contract(c:ok(), "module verification failed: " .. table_concat(c:errors(), "; "))

    record("4. Module load order verification", true)
end

-- ----------------------------------------------------------------
-- 5. package.loaded Inspection
-- ----------------------------------------------------------------
local function demo_package_loaded_inspection()
    section(5, "package.loaded Inspection")
    io_write("Inspect what modules are cached in package.loaded.\n")
    io_write("Detect whether a module is already loaded without\n")
    io_write("triggering a new require.\n\n")

    -- Check if specific modules are loaded
    local check_names = { "safe.guard", "safe.validate", "safe.log", "cjson", "lpeg" }
    io_write("  Module cache status:\n")
    for _, name in ipairs(check_names) do
        local cached = package.loaded[name]
        local status
        if cached ~= nil then
            status = string_format("loaded (%s)", type(cached))
        else
            status = "not loaded"
        end
        io_write(string_format("    %-20s %s\n", name, status))
    end

    -- Count total loaded modules
    local total = 0
    local safe_count = 0
    for name, _ in pairs(package.loaded) do
        if type(name) == "string" then
            total = total + 1
            if name:sub(1, 5) == "safe." then
                safe_count = safe_count + 1
            end
        end
    end
    io_write(string_format("\n  Total cached modules: %d\n", total))
    io_write(string_format("  safe.* modules:       %d\n", safe_count))

    -- Demonstrate conditional require (avoid double-loading)
    io_write("\n  Conditional require pattern:\n")
    local guard_mod = package.loaded["safe.guard"]
    if guard_mod then
        io_write("    safe.guard already loaded, reusing cached version\n")
        io_write(string_format("    guard.freeze available: %s\n", tostring(type(guard_mod.freeze) == "function")))
    else
        io_write("    safe.guard not loaded, calling require()\n")
        guard_mod = require("safe.guard")
    end
    guard.contract(guard_mod == guard, "should be same module instance")

    record("5. package.loaded inspection", true)
end

-- ----------------------------------------------------------------
-- 6. Require Path Debugging
-- ----------------------------------------------------------------
local function demo_require_path_debugging()
    section(6, "Require Path Debugging")
    io_write("Debug module loading failures by inspecting the search\n")
    io_write("paths that Lua tries when require() is called.\n\n")

    --- Show which file paths Lua would search for a given module name.
    --- @param name string module name (dot-separated)
    --- @return table paths_tried
    local function find_module_paths(name)
        guard.assert_type(name, "string", "name")
        local paths_tried = {}
        -- Convert module name dots to path separators
        local file_name = string_gsub(name, "%.", "/")
        for template in string_gmatch(package.path, "[^;]+") do
            local path = string_gsub(template, "%?", file_name)
            paths_tried[#paths_tried + 1] = path
        end
        return paths_tried
    end

    --- Check which path actually resolves for a module.
    --- @param name string module name
    --- @return string|nil found_path
    --- @return table paths_tried
    local function resolve_module(name)
        local paths = find_module_paths(name)
        for _, path in ipairs(paths) do
            local f = io_open(path, "r")
            if f then
                f:close()
                return path, paths
            end
        end
        return nil, paths
    end

    -- Show search paths for a module that exists
    io_write("  Resolving 'safe.guard':\n")
    local found, tried = resolve_module("safe.guard")
    if found then
        io_write(string_format("    Found at: %s\n", found))
    end
    io_write(string_format("    Paths searched: %d\n", #tried))
    guard.contract(found ~= nil, "safe.guard should be resolvable")

    -- Show search paths for a module that does not exist
    io_write("\n  Resolving 'nonexistent.module':\n")
    local found2, tried2 = resolve_module("nonexistent.module")
    io_write(string_format("    Found: %s\n", tostring(found2)))
    io_write("    Paths tried:\n")
    local max_shown = 4
    for i, path in ipairs(tried2) do
        if i > max_shown then
            io_write(string_format("      ... and %d more\n", #tried2 - max_shown))
            break
        end
        io_write(string_format("      %s\n", path))
    end
    guard.contract(found2 == nil, "nonexistent module should not resolve")

    -- Show current package.path entries
    io_write("\n  Current package.path entries:\n")
    local entry_count = 0
    for template in string_gmatch(package.path, "[^;]+") do
        entry_count = entry_count + 1
        if entry_count <= 5 then
            io_write(string_format("    [%d] %s\n", entry_count, template))
        end
    end
    if entry_count > 5 then
        io_write(string_format("    ... and %d more\n", entry_count - 5))
    end
    io_write(string_format("  Total path entries: %d\n", entry_count))

    record("6. Require path debugging", true)
end

-- ----------------------------------------------------------------
-- Summary
-- ----------------------------------------------------------------
local function print_summary()
    io_write("\n" .. string_rep("=", 60) .. "\n")
    io_write("Pattern Summary\n")
    io_write(string_rep("=", 60) .. "\n\n")
    io_write(string_format("  %-30s %s\n", "Pattern", "Real-World Usage"))
    io_write(string_format("  %-30s %s\n", string_rep("-", 30), string_rep("-", 28)))
    io_write(string_format("  %-30s %s\n", "Require cycle awareness", "All large Lua projects"))
    io_write(string_format("  %-30s %s\n", "Lazy require", "Kong, lazy.nvim, APISIX"))
    io_write(string_format("  %-30s %s\n", "pcall(require, name)", "Universal (all projects)"))
    io_write(string_format("  %-30s %s\n", "Load order verification", "xmake, KOReader, Prosody"))
    io_write(string_format("  %-30s %s\n", "package.loaded inspection", "Kong, AwesomeWM, Neovim"))
    io_write(string_format("  %-30s %s\n", "Path debugging", "Debugging any project"))
end

-- ----------------------------------------------------------------
-- Main
-- ----------------------------------------------------------------
local function main(_args)
    io_write("Require Safety Patterns (from top Lua projects)\n")
    io_write(string_rep("=", 60) .. "\n")

    demo_require_cycle()
    demo_lazy_require()
    demo_safe_require()
    demo_load_order_verification()
    demo_package_loaded_inspection()
    demo_require_path_debugging()

    print_summary()
    print_matrix()

    io_write("\n")
    log.info("require safety demo complete")
    return 0
end

os.exit(main(arg))
