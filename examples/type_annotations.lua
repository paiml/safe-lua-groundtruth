#!/usr/bin/env lua5.1
--[[
  type_annotations.lua — Example: LuaLS and LDoc type annotation systems.
  Demonstrates both annotation standards side-by-side: the modern LuaLS /
  sumneko system (used by lazy.nvim, growing in KOReader) and the legacy
  LDoc system (used by AwesomeWM, Hammerspoon). Shows how runtime type
  checking via guard/validate complements static annotations.

  Usage: lua5.1 examples/type_annotations.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local type = type
local setmetatable = setmetatable
local tostring = tostring
local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local string_format = string.format
local string_rep = string.rep

log.set_level(log.INFO)
log.set_context("annotations")

local function banner(title)
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("  %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- System 1: LuaLS / sumneko annotations (modern)
--
-- Used by lazy.nvim, growing adoption in KOReader and lite-xl.
-- Recognized by lua-language-server for inline hover docs, type
-- checking, and go-to-definition in Neovim/VSCode.
-- ================================================================

---@class Point
---@field x number X coordinate
---@field y number Y coordinate
local Point = {}
Point.__index = Point

---Create a new Point.
---@param x number X coordinate
---@param y number Y coordinate
---@return Point
function Point.new(x, y)
    guard.assert_type(x, "number", "x")
    guard.assert_type(y, "number", "y")
    return setmetatable({ x = x, y = y }, Point)
end

---Euclidean distance from this point to another.
---@param other Point target point
---@return number distance
function Point:distance_to(other)
    guard.assert_type(other, "table", "other")
    guard.assert_not_nil(other.x, "other.x")
    guard.assert_not_nil(other.y, "other.y")
    local dx = self.x - other.x
    local dy = self.y - other.y
    return math_sqrt(dx * dx + dy * dy)
end

---Translate this point by an offset, returning a new Point.
---@param dx number horizontal offset
---@param dy number vertical offset
---@return Point translated copy
function Point:translate(dx, dy)
    guard.assert_type(dx, "number", "dx")
    guard.assert_type(dy, "number", "dy")
    return Point.new(self.x + dx, self.y + dy)
end

---String representation.
---@return string
function Point:describe()
    return string_format("Point(%.1f, %.1f)", self.x, self.y)
end

-- ================================================================
-- System 2: LDoc annotations (legacy)
--
-- Used by AwesomeWM, Hammerspoon, Penlight, LuaSocket.
-- Recognized by the ldoc documentation generator to produce
-- HTML/Markdown API reference sites.
-- ================================================================

--- A rectangle with position and size.
-- @type Rect
local Rect = {}
Rect.__index = Rect

--- Create a new rectangle.
-- @tparam number x X position of top-left corner
-- @tparam number y Y position of top-left corner
-- @tparam number w Width (must be positive)
-- @tparam number h Height (must be positive)
-- @treturn Rect the new rectangle
function Rect.new(x, y, w, h)
    local c = validate.Checker:new()
    c:check_type(x, "number", "x")
    c:check_type(y, "number", "y")
    c:check_type(w, "number", "w")
    c:check_type(h, "number", "h")
    c:check_range(w, 0.001, 1e9, "w")
    c:check_range(h, 0.001, 1e9, "h")
    c:assert()
    return setmetatable({ x = x, y = y, w = w, h = h }, Rect)
end

--- Get the area of this rectangle.
-- @treturn number area
function Rect:area()
    return self.w * self.h
end

--- Get the perimeter of this rectangle.
-- @treturn number perimeter
function Rect:perimeter()
    return 2 * (self.w + self.h)
end

--- Get the center point of this rectangle.
-- @treturn Point center
function Rect:center()
    return Point.new(self.x + self.w / 2, self.y + self.h / 2)
end

--- Check if this rectangle contains a point.
-- @tparam Point p the point to test
-- @treturn boolean true if the point is inside
function Rect:contains_point(p)
    guard.assert_type(p, "table", "p")
    return p.x >= self.x and p.x <= self.x + self.w and p.y >= self.y and p.y <= self.y + self.h
end

--- Check if this rectangle overlaps another rectangle.
-- @tparam Rect other the other rectangle
-- @treturn boolean true if the rectangles overlap
function Rect:overlaps(other)
    guard.assert_type(other, "table", "other")
    if self.x + self.w <= other.x then
        return false
    end
    if other.x + other.w <= self.x then
        return false
    end
    if self.y + self.h <= other.y then
        return false
    end
    if other.y + other.h <= self.y then
        return false
    end
    return true
end

--- Compute the intersection rectangle of two overlapping rects.
-- @tparam Rect other the other rectangle
-- @treturn Rect|nil intersection rectangle, or nil if no overlap
function Rect:intersection(other)
    guard.assert_type(other, "table", "other")
    if not self:overlaps(other) then
        return nil
    end
    local ix = math_max(self.x, other.x)
    local iy = math_max(self.y, other.y)
    local ix2 = math_min(self.x + self.w, other.x + other.w)
    local iy2 = math_min(self.y + self.h, other.y + other.h)
    return Rect.new(ix, iy, ix2 - ix, iy2 - iy)
end

--- String representation.
-- @treturn string description
function Rect:describe()
    return string_format("Rect(%.1f, %.1f, %.1f x %.1f)", self.x, self.y, self.w, self.h)
end

-- ================================================================
-- Combined: Shape interface with both annotation styles
--
-- Shows how you might document a polymorphic interface using
-- each system. Both styles are pure comments and have zero
-- runtime effect.
-- ================================================================

--- LuaLS style: Shape interface
---@class Shape
---@field kind string shape type name
---@field describe fun(self: Shape): string

--- LDoc style: Shape interface
-- @type Shape
-- @field kind string the shape type name
-- @function describe
-- @treturn string human-readable description

-- ================================================================
-- Geometry helpers that accept both Point and Rect
-- ================================================================

---Compute the bounding box of a list of points (LuaLS style).
---@param points Point[] array of Point objects
---@return Rect bounding rectangle
local function bounding_box(points)
    guard.assert_type(points, "table", "points")
    guard.contract(#points >= 1, "need at least one point")

    local min_x, min_y = points[1].x, points[1].y
    local max_x, max_y = min_x, min_y
    for i = 2, #points do
        local p = points[i]
        if p.x < min_x then
            min_x = p.x
        end
        if p.y < min_y then
            min_y = p.y
        end
        if p.x > max_x then
            max_x = p.x
        end
        if p.y > max_y then
            max_y = p.y
        end
    end
    return Rect.new(min_x, min_y, max_x - min_x, max_y - min_y)
end

--- Check approximate equality of two numbers (LDoc style).
-- @tparam number a first value
-- @tparam number b second value
-- @tparam[opt=0.001] number epsilon tolerance
-- @treturn boolean true if |a - b| < epsilon
local function approx_equal(a, b, epsilon)
    epsilon = epsilon or 0.001
    return math_abs(a - b) < epsilon
end

-- ================================================================
-- Demonstrations
-- ================================================================

local function demo_luals_point()
    banner("LuaLS / sumneko Annotations (Point)")

    local origin = Point.new(0, 0)
    local target = Point.new(3, 4)
    local dist = origin:distance_to(target)
    local moved = target:translate(1, -1)

    io.write(string_format("  origin:   %s\n", origin:describe()))
    io.write(string_format("  target:   %s\n", target:describe()))
    io.write(string_format("  distance: %.2f (expected 5.00)\n", dist))
    io.write(string_format("  moved:    %s\n", moved:describe()))

    guard.contract(approx_equal(dist, 5.0), "3-4-5 triangle distance")
    log.info("Point operations verified")
end

local function demo_ldoc_rect()
    banner("LDoc Annotations (Rect)")

    local r1 = Rect.new(0, 0, 10, 8)
    local r2 = Rect.new(5, 3, 12, 6)

    io.write(string_format("  r1:          %s  area=%.0f  perim=%.0f\n", r1:describe(), r1:area(), r1:perimeter()))
    io.write(string_format("  r2:          %s  area=%.0f  perim=%.0f\n", r2:describe(), r2:area(), r2:perimeter()))
    io.write(string_format("  r1 center:   %s\n", r1:center():describe()))
    io.write(string_format("  r2 center:   %s\n", r2:center():describe()))
    io.write(string_format("  overlaps?    %s\n", tostring(r1:overlaps(r2))))

    local inter = r1:intersection(r2)
    if inter then
        io.write(string_format("  intersection: %s  area=%.0f\n", inter:describe(), inter:area()))
    end

    local inside = Point.new(3, 4)
    local outside = Point.new(20, 20)
    io.write(string_format("  r1 contains %s? %s\n", inside:describe(), tostring(r1:contains_point(inside))))
    io.write(string_format("  r1 contains %s? %s\n", outside:describe(), tostring(r1:contains_point(outside))))

    log.info("Rect operations verified")
end

local function demo_combined()
    banner("Combined: Bounding Box + Collision")

    local points = {
        Point.new(2, 1),
        Point.new(8, 3),
        Point.new(5, 9),
        Point.new(1, 6),
    }

    io.write("  Points:\n")
    for i = 1, #points do
        io.write(string_format("    [%d] %s\n", i, points[i]:describe()))
    end

    local bbox = bounding_box(points)
    io.write(string_format("  Bounding box: %s\n", bbox:describe()))
    io.write(string_format("  Bbox area:    %.0f\n", bbox:area()))

    -- Collision detection with a query rect
    local query = Rect.new(4, 4, 3, 3)
    io.write(string_format("  Query rect:   %s\n", query:describe()))
    io.write(string_format("  Overlaps bbox? %s\n", tostring(bbox:overlaps(query))))

    local inter = bbox:intersection(query)
    if inter then
        io.write(string_format("  Intersection: %s  area=%.0f\n", inter:describe(), inter:area()))
    end

    log.info("bounding box and collision verified")
end

local function demo_runtime_pairing()
    banner("Runtime Checks Pair with Annotations")

    io.write("  Annotations are comments: zero runtime cost.\n")
    io.write("  Runtime guards catch actual misuse at call time.\n\n")

    -- Demonstrate guard catching wrong type at runtime
    local ok, err = pcall(Point.new, "not-a-number", 5)
    io.write(string_format("  Point.new(string, 5):  ok=%s\n", tostring(ok)))
    io.write(string_format("    error: %s\n", tostring(err)))

    -- Demonstrate validate.Checker catching bad rect dims
    ok, err = pcall(Rect.new, 0, 0, -1, 5)
    io.write(string_format("  Rect.new(0,0,-1,5):    ok=%s\n", tostring(ok)))
    io.write(string_format("    error: %s\n", tostring(err)))

    -- Show that annotation comments have no type() footprint
    io.write(string_format("\n  type(Point) = %s  (annotations are invisible)\n", type(Point)))
    io.write(string_format("  type(Rect)  = %s  (annotations are invisible)\n", type(Rect)))

    log.info("runtime + annotation pairing demonstrated")
end

local function print_comparison()
    banner("Comparison Matrix: LuaLS vs LDoc")

    local rows = {
        { "Feature", "LuaLS / sumneko", "LDoc" },
        { "Class", "---@class Name", "-- @type Name" },
        { "Field", "---@field x number", "-- @field x number desc" },
        { "Param", "---@param x number", "-- @tparam number x desc" },
        { "Return", "---@return number", "-- @treturn number desc" },
        { "Optional", "---@param x? number", "-- @tparam[opt] number x" },
        { "Alias / Typedef", "---@alias Name type", "-- @alias Name (limited)" },
        { "Generic", "---@generic T", "Not supported" },
        { "Overload", "---@overload fun(a:T):R", "Not supported" },
        { "Tooling", "lua-language-server (IDE)", "ldoc (doc generator)" },
        { "Projects", "lazy.nvim, KOReader", "AwesomeWM, Hammerspoon" },
        { "Runtime effect", "None (comments only)", "None (comments only)" },
    }

    -- Calculate column widths
    local widths = { 0, 0, 0 }
    for i = 1, #rows do
        for j = 1, 3 do
            local len = #rows[i][j]
            if len > widths[j] then
                widths[j] = len
            end
        end
    end

    local fmt = string_format("  %%-%ds  %%-%ds  %%-%ds\n", widths[1], widths[2], widths[3])

    io.write(string_format(fmt, rows[1][1], rows[1][2], rows[1][3]))
    io.write(
        "  "
            .. string_rep("-", widths[1])
            .. "  "
            .. string_rep("-", widths[2])
            .. "  "
            .. string_rep("-", widths[3])
            .. "\n"
    )

    for i = 2, #rows do
        io.write(string_format(fmt, rows[i][1], rows[i][2], rows[i][3]))
    end
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("Type Annotations in Lua 5.1\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("LuaLS (modern) vs LDoc (legacy) annotation systems,\n")
    io.write("paired with safe-lua runtime type checking.\n")

    demo_luals_point()
    demo_ldoc_rect()
    demo_combined()
    demo_runtime_pairing()
    print_comparison()

    io.write("\n" .. string_rep("=", 60) .. "\n")
    log.info("all annotation demos completed successfully")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
