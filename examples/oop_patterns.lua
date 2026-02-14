#!/usr/bin/env lua5.1
--[[
  oop_patterns.lua — Example: five OOP patterns from top Lua projects.
  Demonstrates separate-metatable, prototypal inheritance, __call
  constructor, self-as-metatable, and copy-based inheritance — the
  five idioms found across Kong, KOReader, lazy.nvim, AwesomeWM,
  lite-xl, and xmake.

  Usage: lua5.1 examples/oop_patterns.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local type = type
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local string_format = string.format
local string_rep = string.rep

log.set_level(log.INFO)
log.set_context("oop")

local function banner(title)
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("Pattern: %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- Pattern 1: Separate Metatable (Kong / APISIX style)
--
-- The module table doubles as the method namespace.
-- A private metatable with __index = M wires up methods.
-- Constructors return setmetatable({...}, mt).
-- ================================================================

local Service = {}
local service_mt = { __index = Service }

function Service.new(name, port)
    guard.assert_type(name, "string", "name")
    guard.assert_type(port, "number", "port")
    guard.contract(port > 0 and port < 65536, "port out of range")
    return setmetatable({ _name = name, _port = port, _healthy = true }, service_mt)
end

function Service:health_check()
    log.info("checking health of %s:%d", self._name, self._port)
    return self._healthy
end

function Service:set_unhealthy()
    self._healthy = false
end

function Service:describe()
    local status = self._healthy and "UP" or "DOWN"
    return string_format("%s (port %d) [%s]", self._name, self._port, status)
end

local function demo_separate_metatable()
    banner("1. Separate Metatable (Kong/APISIX)")

    local svc = Service.new("auth-api", 8443)
    io.write("  Created:  " .. svc:describe() .. "\n")
    io.write("  Healthy?  " .. tostring(svc:health_check()) .. "\n")

    svc:set_unhealthy()
    io.write("  After failure: " .. svc:describe() .. "\n")
end

-- ================================================================
-- Pattern 2: Prototypal Inheritance (KOReader / lite-xl style)
--
-- A base object has an :extend() method that creates a child
-- whose metatable is the parent itself (__index = self).
-- Children inherit all methods and can override them.
-- ================================================================

local Widget = {}
Widget.__index = Widget

function Widget:extend(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Widget:init(kind, width, height)
    local c = validate.Checker:new()
    c:check_string_not_empty(kind, "kind")
    c:check_type(width, "number", "width")
    c:check_type(height, "number", "height")
    c:check_range(width, 1, 10000, "width")
    c:check_range(height, 1, 10000, "height")
    c:assert()

    self._kind = kind
    self._width = width
    self._height = height
    return self
end

function Widget:area()
    return self._width * self._height
end

function Widget:describe()
    return string_format("%s (%dx%d)", self._kind, self._width, self._height)
end

local Button = Widget:extend()

function Button:init(label, width, height)
    Widget.init(self, "button", width, height)
    guard.assert_type(label, "string", "label")
    self._label = label
    return self
end

function Button:describe()
    return string_format("Button[%s] (%dx%d)", self._label, self._width, self._height)
end

local function demo_prototypal_inheritance()
    banner("2. Prototypal Inheritance (KOReader/lite-xl)")

    local w = Widget:extend():init("panel", 800, 600)
    io.write("  Widget: " .. w:describe() .. "  area=" .. tostring(w:area()) .. "\n")

    local b = Button:extend():init("OK", 120, 40)
    io.write("  Button: " .. b:describe() .. "  area=" .. tostring(b:area()) .. "\n")
end

-- ================================================================
-- Pattern 3: __call Constructor (lazy.nvim / AwesomeWM style)
--
-- The module table gets a __call metamethod so that
-- M(...) is syntactic sugar for M.new(...).
-- ================================================================

local Color = {}
local color_mt = { __index = Color }

function Color.new(r, g, b)
    local c = validate.Checker:new()
    c:check_range(r, 0, 255, "r")
    c:check_range(g, 0, 255, "g")
    c:check_range(b, 0, 255, "b")
    c:assert()
    return setmetatable({ _r = r, _g = g, _b = b }, color_mt)
end

function Color:hex()
    return string_format("#%02X%02X%02X", self._r, self._g, self._b)
end

function Color:describe()
    return string_format("rgb(%d, %d, %d) = %s", self._r, self._g, self._b, self:hex())
end

setmetatable(Color, {
    __call = function(_, ...)
        return Color.new(...)
    end,
})

local function demo_call_constructor()
    banner("3. __call Constructor (lazy.nvim/AwesomeWM)")

    local red = Color.new(255, 0, 0)
    io.write("  Via .new():  " .. red:describe() .. "\n")

    local blue = Color(0, 0, 255)
    io.write("  Via __call:  " .. blue:describe() .. "\n")
end

-- ================================================================
-- Pattern 4: Self-as-Metatable (xmake style)
--
-- The object IS its own metatable.  __index points at itself.
-- New instances clone fields and set the prototype as metatable.
-- Compact: no separate mt table needed.
-- ================================================================

local Task = { _type = "Task" }
Task.__index = Task

function Task:new(name, priority)
    guard.assert_type(name, "string", "name")
    guard.assert_type(priority, "number", "priority")
    guard.contract(priority >= 1 and priority <= 5, "priority must be 1-5")

    local instance = { _name = name, _priority = priority, _done = false }
    setmetatable(instance, instance) -- self-as-metatable
    instance.__index = Task -- inherit from Task
    return instance
end

function Task:complete()
    self._done = true
end

function Task:describe()
    local status = self._done and "DONE" or "OPEN"
    return string_format("[P%d] %s (%s)", self._priority, self._name, status)
end

local function demo_self_as_metatable()
    banner("4. Self-as-Metatable (xmake)")

    local t1 = Task:new("build", 1)
    local t2 = Task:new("test", 2)
    t1:complete()
    io.write("  Task 1: " .. t1:describe() .. "\n")
    io.write("  Task 2: " .. t2:describe() .. "\n")

    -- Demonstrate that instance IS its own metatable
    local mt = getmetatable(t1)
    io.write("  t1 == getmetatable(t1)? " .. tostring(mt == t1) .. "\n")
end

-- ================================================================
-- Pattern 5: Copy-based Inheritance (AwesomeWM style)
--
-- Instead of metatable delegation, functions are copied from
-- the base into the child table.  No chain lookups at runtime.
-- Good for hot paths where __index overhead matters.
-- ================================================================

local Emitter = {}

function Emitter.on(self, event, handler)
    guard.assert_type(event, "string", "event")
    guard.assert_type(handler, "function", "handler")
    if not self._handlers then
        self._handlers = {}
    end
    if not self._handlers[event] then
        self._handlers[event] = {}
    end
    local list = self._handlers[event]
    list[#list + 1] = handler
end

function Emitter.emit(self, event, ...)
    guard.assert_type(event, "string", "event")
    local list = guard.safe_get(self, "_handlers", event)
    if not list then
        return
    end
    for i = 1, #list do
        list[i](...)
    end
end

local function copy_methods(base, child)
    for k, v in pairs(base) do
        if type(v) == "function" then
            child[k] = v
        end
    end
end

local function demo_copy_based_inheritance()
    banner("5. Copy-based Inheritance (AwesomeWM)")

    -- Logger is a plain table that gets Emitter methods copied in
    local logger = { _name = "app-logger" }
    copy_methods(Emitter, logger)

    local messages = {}
    logger.on(logger, "log", function(msg)
        messages[#messages + 1] = msg
    end)
    logger.on(logger, "log", function(msg)
        io.write("  [listener] " .. msg .. "\n")
    end)

    logger.emit(logger, "log", "boot complete")
    logger.emit(logger, "log", "ready for traffic")

    io.write(string_format("  Total captured messages: %d\n", #messages))
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("OOP Patterns in Lua 5.1\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Five idioms from Kong, KOReader, lazy.nvim, AwesomeWM,\n")
    io.write("lite-xl, and xmake — with safe-lua defensive validation.\n")

    demo_separate_metatable()
    demo_prototypal_inheritance()
    demo_call_constructor()
    demo_self_as_metatable()
    demo_copy_based_inheritance()

    io.write("\n" .. string_rep("=", 60) .. "\n")
    log.info("all five OOP patterns demonstrated successfully")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
