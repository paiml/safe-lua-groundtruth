#!/usr/bin/env lua5.1
--[[
  observer_pattern.lua — Example: signal/event and observable patterns.
  Demonstrates SignalEmitter (AwesomeWM gears.object), WeakEmitter
  (weak_connect_signal with GC auto-cleanup), and Observable
  (Hammerspoon watchable.lua KVO-style __newindex notification).

  Usage: lua5.1 examples/observer_pattern.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local string_format = string.format
local string_rep = string.rep
local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove
local collectgarbage = collectgarbage

log.set_level(log.INFO)
log.set_context("observer")

local function banner(title)
    guard.assert_type(title, "string", "title")
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("  %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- SignalEmitter — full signal/event system (AwesomeWM gears.object)
-- ================================================================

local SignalEmitter = {}
local emitter_mt = { __index = SignalEmitter }

function SignalEmitter.new()
    return setmetatable({ _signals = {}, _wildcards = {} }, emitter_mt)
end

function SignalEmitter:connect(signal_name, handler)
    guard.assert_type(signal_name, "string", "signal_name")
    guard.assert_type(handler, "function", "handler")
    if not self._signals[signal_name] then
        self._signals[signal_name] = {}
    end
    local list = self._signals[signal_name]
    list[#list + 1] = handler
end

function SignalEmitter:disconnect(signal_name, handler)
    guard.assert_type(signal_name, "string", "signal_name")
    guard.assert_type(handler, "function", "handler")
    local list = self._signals[signal_name]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == handler then
            table_remove(list, i)
            return
        end
    end
end

function SignalEmitter:emit(signal_name, ...)
    guard.assert_type(signal_name, "string", "signal_name")
    local list = self._signals[signal_name]
    if list then
        for i = 1, #list do
            list[i](...)
        end
    end
    for i = 1, #self._wildcards do
        self._wildcards[i](signal_name, ...)
    end
end

function SignalEmitter:once(signal_name, handler)
    guard.assert_type(signal_name, "string", "signal_name")
    guard.assert_type(handler, "function", "handler")
    local emitter = self
    local function wrapper(...)
        emitter:disconnect(signal_name, wrapper)
        handler(...)
    end
    self:connect(signal_name, wrapper)
end

function SignalEmitter:connect_wildcard(handler)
    guard.assert_type(handler, "function", "handler")
    self._wildcards[#self._wildcards + 1] = handler
end

-- ================================================================
-- WeakEmitter — variant with weak listener references
-- ================================================================

local WeakEmitter = {}
local weak_emitter_mt = { __index = WeakEmitter }

function WeakEmitter.new()
    return setmetatable({ _signals = {} }, weak_emitter_mt)
end

function WeakEmitter:connect(signal_name, handler)
    guard.assert_type(signal_name, "string", "signal_name")
    guard.assert_type(handler, "function", "handler")
    if not self._signals[signal_name] then
        self._signals[signal_name] = setmetatable({}, { __mode = "v" })
    end
    local list = self._signals[signal_name]
    list[#list + 1] = handler
end

function WeakEmitter:emit(signal_name, ...)
    guard.assert_type(signal_name, "string", "signal_name")
    local list = self._signals[signal_name]
    if not list then
        return
    end
    for i = 1, #list do
        local h = list[i]
        if h then
            h(...)
        end
    end
end

function WeakEmitter:handler_count(signal_name)
    guard.assert_type(signal_name, "string", "signal_name")
    local list = self._signals[signal_name]
    if not list then
        return 0
    end
    local n = 0
    for i = 1, #list do
        if list[i] then
            n = n + 1
        end
    end
    return n
end

-- ================================================================
-- Observable — KVO-style observable table (Hammerspoon watchable)
-- ================================================================

local Observable = {}
local observable_mt = {}

function Observable.new(initial_data)
    local data = {}
    local watchers = {}
    if initial_data then
        guard.assert_type(initial_data, "table", "initial_data")
        for k, v in pairs(initial_data) do
            data[k] = v
        end
    end
    local proxy = { _data = data, _watchers = watchers }
    observable_mt.__index = function(_, key)
        if key == "watch" or key == "unwatch" then
            return Observable[key]
        end
        return data[key]
    end
    observable_mt.__newindex = function(_, key, new_value)
        local old_value = data[key]
        data[key] = new_value
        local kw = watchers[key]
        if kw then
            for i = 1, #kw do
                kw[i](key, old_value, new_value)
            end
        end
    end
    return setmetatable(proxy, observable_mt)
end

function Observable:watch(key, handler)
    guard.assert_type(key, "string", "key")
    guard.assert_type(handler, "function", "handler")
    if not self._watchers[key] then
        self._watchers[key] = {}
    end
    local list = self._watchers[key]
    list[#list + 1] = handler
end

function Observable:unwatch(key, handler)
    guard.assert_type(key, "string", "key")
    guard.assert_type(handler, "function", "handler")
    local list = self._watchers[key]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == handler then
            table_remove(list, i)
            return
        end
    end
end

-- ================================================================
-- Demos
-- ================================================================

local function demo_signal_emitter()
    banner("1. SignalEmitter (AwesomeWM gears.object)")
    io.write("Pattern: named signals with ordered handler dispatch.\n\n")
    local emitter = SignalEmitter.new()
    local received = {}
    local function on_a(v)
        table_insert(received, string_format("handler-A: %s", tostring(v)))
    end
    local function on_b(v)
        table_insert(received, string_format("handler-B: %s", tostring(v)))
    end
    emitter:connect("data", on_a)
    emitter:connect("data", on_b)
    emitter:emit("data", "first-event")
    io.write(string_format("  After emit: %d messages received\n", #received))
    for _, msg in ipairs(received) do
        io.write(string_format("    %s\n", msg))
    end
    emitter:disconnect("data", on_a)
    emitter:emit("data", "second-event")
    io.write(string_format("  After disconnect + emit: %d total messages\n", #received))
    io.write(string_format("    Last: %s\n", received[#received]))
    log.info("signal emitter demo complete")
end

local function demo_once_and_wildcard()
    banner("2. once() and Wildcard Listeners")
    io.write("Pattern: auto-disconnect after first call; catch-all listener.\n\n")
    local emitter = SignalEmitter.new()
    local once_calls = 0
    local wildcard_log = {}
    emitter:once("init", function(msg)
        once_calls = once_calls + 1
        io.write(string_format("  once-handler fired: %s (call #%d)\n", msg, once_calls))
    end)
    emitter:connect_wildcard(function(signal_name)
        local c = validate.Checker:new()
        c:check_string_not_empty(signal_name, "signal_name")
        if c:ok() then
            table_insert(wildcard_log, signal_name)
        end
    end)
    emitter:emit("init", "booting")
    emitter:emit("init", "should-not-fire")
    emitter:emit("ready", "accepting connections")
    io.write(string_format("  once-handler total calls: %d (expected 1)\n", once_calls))
    io.write(string_format("  Wildcard captured %d signals:", #wildcard_log))
    for _, name in ipairs(wildcard_log) do
        io.write(string_format(" [%s]", name))
    end
    io.write("\n")
    log.info("once and wildcard demo complete")
end

local function demo_weak_listeners()
    banner("3. WeakEmitter — Weak Listener References")
    io.write("Pattern: handlers stored in weak tables; GC removes them.\n\n")
    local emitter = WeakEmitter.new()
    local persistent = function(msg)
        io.write(string_format("  persistent: %s\n", msg))
    end
    emitter:connect("update", persistent)
    do
        local ephemeral = function(msg)
            io.write(string_format("  ephemeral: %s\n", msg))
        end
        emitter:connect("update", ephemeral)
        io.write(string_format("  Before GC: %d handlers\n", emitter:handler_count("update")))
        local _unused = ephemeral -- luacheck: ignore 311
    end
    collectgarbage("collect")
    collectgarbage("collect")
    io.write(string_format("  After GC:  %d live handlers\n", emitter:handler_count("update")))
    emitter:emit("update", "post-gc-event")
    io.write("  Only persistent handler fires after GC.\n")
    guard.assert_not_nil(persistent, "persistent")
    log.info("weak listener demo complete")
end

local function demo_observable_table()
    banner("4. Observable Table (Hammerspoon watchable)")
    io.write("Pattern: __newindex intercepts writes, notifies watchers.\n\n")
    local obs = Observable.new({ host = "localhost", port = 8080 })
    local changes = {}
    local function on_host(key, old_val, new_val)
        guard.assert_type(key, "string", "key")
        local entry = string_format("%s: %s -> %s", key, tostring(old_val), tostring(new_val))
        table_insert(changes, entry)
        io.write(string_format("  Watcher: %s\n", entry))
    end
    local function on_port(key, old_val, new_val)
        guard.assert_type(key, "string", "key")
        local c = validate.Checker:new()
        c:check_type(new_val, "number", "new_port")
        c:check_range(new_val, 1, 65535, "new_port")
        if c:ok() then
            io.write(string_format("  Port watcher: %s changed %s -> %s\n", key, tostring(old_val), tostring(new_val)))
        else
            io.write(string_format("  Port watcher: INVALID — %s\n", tostring(c:errors()[1])))
        end
    end
    obs:watch("host", on_host)
    obs:watch("port", on_port)
    io.write(string_format("  Current: host=%s, port=%s\n", tostring(obs.host), tostring(obs.port)))
    obs.host = "prod.example.com"
    obs.port = 443
    obs:unwatch("host", on_host)
    obs.host = "staging.example.com"
    io.write(string_format("  Total host-change notifications: %d\n", #changes))
    io.write(string_format("  Final host value: %s\n", tostring(obs.host)))
    log.info("observable table demo complete")
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("Observer Pattern — Signal/Event Systems in Lua\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Patterns from AwesomeWM gears.object, Hammerspoon watchable,\n")
    io.write("and APISIX event bus — with safe-lua defensive validation.\n")
    demo_signal_emitter()
    demo_once_and_wildcard()
    demo_weak_listeners()
    demo_observable_table()
    io.write("\n" .. string_rep("=", 60) .. "\n")
    log.info("all observer pattern demos complete")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
