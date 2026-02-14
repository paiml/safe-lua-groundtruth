#!/usr/bin/env lua5.1
--[[
  operator_overloading.lua — Example: metamethod arithmetic & comparison.
  Demonstrates __add, __sub, __mul, __unm, __eq, __lt, __le, __tostring,
  and __concat using immutable Vector2D and Semver types — the patterns
  found across AwesomeWM gears.matrix, lazy.nvim semver.lua, xmake
  hashset.lua, and Hammerspoon geometry.lua.

  Usage: lua5.1 examples/operator_overloading.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local type = type
local setmetatable = setmetatable
local tostring = tostring
local tonumber = tonumber
local math_sqrt = math.sqrt
local string_format = string.format
local string_rep = string.rep
local string_match = string.match

log.set_level(log.INFO)
log.set_context("operator-overloading")

local function banner(title)
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("Section: %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- Type 1: Vector2D — Immutable 2D vector with arithmetic
--
-- Inspired by AwesomeWM gears.matrix (__mul, __eq, __tostring)
-- and Hammerspoon geometry.lua (vector arithmetic).
-- All operations return NEW instances (value-object semantics).
-- ================================================================

local Vector2D = {}
local vector_mt = {}
vector_mt.__index = Vector2D

function Vector2D.new(x, y)
    guard.assert_type(x, "number", "x")
    guard.assert_type(y, "number", "y")
    log.info("creating Vector2D(%s, %s)", tostring(x), tostring(y))
    return setmetatable({ _x = x, _y = y }, vector_mt)
end

function Vector2D:x()
    return self._x
end

function Vector2D:y()
    return self._y
end

function vector_mt.__add(a, b)
    guard.assert_type(a, "table", "lhs")
    guard.assert_type(b, "table", "rhs")
    return Vector2D.new(a._x + b._x, a._y + b._y)
end

function vector_mt.__sub(a, b)
    guard.assert_type(a, "table", "lhs")
    guard.assert_type(b, "table", "rhs")
    return Vector2D.new(a._x - b._x, a._y - b._y)
end

function vector_mt.__mul(a, b)
    -- Support both scalar * vector and vector * scalar
    if type(a) == "number" then
        guard.assert_type(b, "table", "rhs")
        return Vector2D.new(a * b._x, a * b._y)
    elseif type(b) == "number" then
        guard.assert_type(a, "table", "lhs")
        return Vector2D.new(a._x * b, a._y * b)
    else
        guard.contract(false, "Vector2D __mul requires one scalar operand")
    end
end

function vector_mt.__unm(v)
    return Vector2D.new(-v._x, -v._y)
end

function vector_mt.__eq(a, b)
    return a._x == b._x and a._y == b._y
end

function vector_mt.__tostring(v)
    return string_format("Vector2D(%s, %s)", tostring(v._x), tostring(v._y))
end

function vector_mt.__concat(lhs, rhs)
    if type(lhs) == "string" then
        return lhs .. tostring(rhs)
    else
        return tostring(lhs) .. rhs
    end
end

function Vector2D:length()
    return math_sqrt(self._x * self._x + self._y * self._y)
end

function Vector2D:dot(other)
    guard.assert_type(other, "table", "other")
    return self._x * other._x + self._y * other._y
end

-- ================================================================
-- Type 2: Semver — Semantic versioning with comparison operators
--
-- Inspired by lazy.nvim semver.lua (__eq, __lt, __le) and xmake
-- hashset.lua (__eq). Implements full ordering for version
-- comparison with major > minor > patch precedence.
-- ================================================================

local Semver = {}
local semver_mt = {}
semver_mt.__index = Semver

function Semver.new(major, minor, patch)
    local c = validate.Checker:new()
    c:check_type(major, "number", "major")
    c:check_type(minor, "number", "minor")
    c:check_type(patch, "number", "patch")
    c:check_range(major, 0, 999, "major")
    c:check_range(minor, 0, 999, "minor")
    c:check_range(patch, 0, 999, "patch")
    c:assert()
    log.info("creating Semver %d.%d.%d", major, minor, patch)
    return setmetatable({ _major = major, _minor = minor, _patch = patch }, semver_mt)
end

function Semver.parse(str)
    guard.assert_type(str, "string", "version string")
    local maj, min, pat = string_match(str, "^(%d+)%.(%d+)%.(%d+)$")
    guard.contract(maj ~= nil, "invalid semver format: expected 'x.y.z', got '" .. str .. "'")
    return Semver.new(tonumber(maj), tonumber(min), tonumber(pat))
end

function Semver:major()
    return self._major
end

function Semver:minor()
    return self._minor
end

function Semver:patch()
    return self._patch
end

function semver_mt.__eq(a, b)
    return a._major == b._major and a._minor == b._minor and a._patch == b._patch
end

function semver_mt.__lt(a, b)
    if a._major ~= b._major then
        return a._major < b._major
    end
    if a._minor ~= b._minor then
        return a._minor < b._minor
    end
    return a._patch < b._patch
end

function semver_mt.__le(a, b)
    return a == b or a < b
end

function semver_mt.__tostring(v)
    return string_format("%d.%d.%d", v._major, v._minor, v._patch)
end

function Semver:is_compatible(other)
    guard.assert_type(other, "table", "other")
    local same_major = self._major == other._major
    local minor_ok = self._minor >= other._minor
    log.info(
        "compatibility check: %s vs %s => same_major=%s, minor_ok=%s",
        tostring(self),
        tostring(other),
        tostring(same_major),
        tostring(minor_ok)
    )
    return same_major and minor_ok
end

-- ================================================================
-- Demo: Vector Arithmetic
-- ================================================================

local function demo_vector_arithmetic()
    banner("1. Vector2D Arithmetic (__add, __sub, __mul, __unm)")

    local a = Vector2D.new(3, 4)
    local b = Vector2D.new(1, 2)

    local sum = a + b
    io.write(string_format("  %s + %s = %s\n", tostring(a), tostring(b), tostring(sum)))

    local diff = a - b
    io.write(string_format("  %s - %s = %s\n", tostring(a), tostring(b), tostring(diff)))

    local scaled = 2 * a
    io.write(string_format("  2 * %s = %s\n", tostring(a), tostring(scaled)))

    local scaled_r = b * 3
    io.write(string_format("  %s * 3 = %s\n", tostring(b), tostring(scaled_r)))

    local neg = -a
    io.write(string_format("  -%s = %s\n", tostring(a), tostring(neg)))

    io.write(string_format("  length(%s) = %.4f\n", tostring(a), a:length()))
    io.write(string_format("  dot(%s, %s) = %s\n", tostring(a), tostring(b), tostring(a:dot(b))))

    -- __concat demonstration
    local msg = "Result: " .. sum
    io.write(string_format("  __concat: %s\n", msg))
end

-- ================================================================
-- Demo: Vector Comparison
-- ================================================================

local function demo_vector_comparison()
    banner("2. Vector2D Comparison (__eq, __tostring)")

    local u = Vector2D.new(5, 10)
    local v = Vector2D.new(5, 10)
    local w = Vector2D.new(10, 5)

    io.write(string_format("  %s == %s ? %s\n", tostring(u), tostring(v), tostring(u == v)))
    io.write(string_format("  %s == %s ? %s\n", tostring(u), tostring(w), tostring(u == w)))

    -- Immutability: operations create new instances
    local sum = u + v
    io.write(string_format("  After u + v: u is still %s (immutable)\n", tostring(u)))
    io.write(string_format("  u + v produced new %s\n", tostring(sum)))

    -- Accessor methods
    io.write(string_format("  u:x() = %s, u:y() = %s\n", tostring(u:x()), tostring(u:y())))
end

-- ================================================================
-- Demo: Semver Ordering
-- ================================================================

local function demo_semver_ordering()
    banner("3. Semver Ordering (__eq, __lt, __le, __tostring)")

    local v1 = Semver.new(1, 0, 0)
    local v2 = Semver.new(1, 2, 0)
    local v3 = Semver.new(1, 2, 3)
    local v4 = Semver.new(2, 0, 0)

    io.write(string_format("  %s == %s ? %s\n", tostring(v1), tostring(v1), tostring(v1 == v1)))
    io.write(string_format("  %s == %s ? %s\n", tostring(v1), tostring(v2), tostring(v1 == v2)))
    io.write(string_format("  %s <  %s ? %s\n", tostring(v1), tostring(v2), tostring(v1 < v2)))
    io.write(string_format("  %s <  %s ? %s\n", tostring(v2), tostring(v3), tostring(v2 < v3)))
    io.write(string_format("  %s <= %s ? %s\n", tostring(v3), tostring(v3), tostring(v3 <= v3)))
    io.write(string_format("  %s <  %s ? %s\n", tostring(v3), tostring(v4), tostring(v3 < v4)))

    -- Semver.parse
    local parsed = Semver.parse("3.14.159")
    io.write(string_format("  Semver.parse('3.14.159') = %s\n", tostring(parsed)))

    -- Sort demonstration using comparison operators
    local versions = { v4, v1, v3, v2 }
    table.sort(versions, function(a, b)
        return a < b
    end)
    io.write("  Sorted: ")
    for i = 1, #versions do
        if i > 1 then
            io.write(" < ")
        end
        io.write(tostring(versions[i]))
    end
    io.write("\n")

    -- Accessor methods
    io.write(string_format("  v3:major()=%d, v3:minor()=%d, v3:patch()=%d\n", v3:major(), v3:minor(), v3:patch()))
end

-- ================================================================
-- Demo: Semver Compatibility
-- ================================================================

local function demo_semver_compatibility()
    banner("4. Semver Compatibility (is_compatible)")

    local lib_v = Semver.new(2, 5, 0)
    local req_a = Semver.new(2, 3, 0)
    local req_b = Semver.new(2, 7, 0)
    local req_c = Semver.new(3, 0, 0)

    io.write(string_format("  Library version: %s\n", tostring(lib_v)))
    io.write(
        string_format("  Requires >= %s ? compatible = %s\n", tostring(req_a), tostring(lib_v:is_compatible(req_a)))
    )
    io.write(
        string_format("  Requires >= %s ? compatible = %s\n", tostring(req_b), tostring(lib_v:is_compatible(req_b)))
    )
    io.write(
        string_format("  Requires >= %s ? compatible = %s\n", tostring(req_c), tostring(lib_v:is_compatible(req_c)))
    )

    -- Use guard.safe_get to demonstrate nil-safe access
    local maybe_ver = { release = { current = Semver.new(1, 0, 0) } }
    local found = guard.safe_get(maybe_ver, "release", "current")
    io.write(string_format("  safe_get found: %s\n", tostring(found)))
    local missing = guard.safe_get(maybe_ver, "release", "next")
    io.write(string_format("  safe_get missing: %s\n", tostring(missing)))
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("Operator Overloading in Lua 5.1\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Metamethod arithmetic & comparison from AwesomeWM,\n")
    io.write("lazy.nvim, xmake, and Hammerspoon — with safe-lua\n")
    io.write("defensive validation.\n")

    demo_vector_arithmetic()
    demo_vector_comparison()
    demo_semver_ordering()
    demo_semver_compatibility()

    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("Metamethods demonstrated:\n")
    io.write("  __add, __sub, __mul, __unm  (Vector2D arithmetic)\n")
    io.write("  __eq, __lt, __le            (Semver comparison)\n")
    io.write("  __tostring, __concat        (string conversion)\n")
    io.write(string_rep("=", 60) .. "\n")
    log.info("all operator overloading patterns demonstrated successfully")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
