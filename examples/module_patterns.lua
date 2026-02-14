#!/usr/bin/env lua5.1
--[[
  module_patterns.lua — Example: module definition idioms from top Lua projects.
  Demonstrates return-table, callable module, stdlib extension, private
  constructor, hierarchical namespace, lazy-init, and versioning — idioms
  from APISIX core.table, AwesomeWM gears.cache, Kong PDK, xmake, and lpeg.

  Usage: lua5.1 examples/module_patterns.lua
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
local rawget = rawget

log.set_level(log.INFO)
log.set_context("module-patterns")

local function banner(title)
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("Pattern: %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- Pattern 1: Return-Table Module — the standard pattern (safe-lua itself)

local function make_greeter()
    local M = {}
    function M.hello(name)
        guard.assert_type(name, "string", "name")
        return string_format("Hello, %s!", name)
    end
    function M.goodbye(name)
        guard.assert_type(name, "string", "name")
        return string_format("Goodbye, %s!", name)
    end
    return M
end

local function demo_return_table()
    banner("1. Return-Table Module (standard)")
    local g = make_greeter()
    io.write('  hello("Lua")   = ' .. g.hello("Lua") .. "\n")
    io.write('  goodbye("Lua") = ' .. g.goodbye("Lua") .. "\n")
    log.info("return-table: simplest pattern, dot syntax, no metatable")
end

-- Pattern 2: Module with __call (AwesomeWM gears.cache pattern)

local function make_cache_module()
    local M = {}
    local mt = { __index = M }

    function M.new(max_size)
        guard.assert_type(max_size, "number", "max_size")
        guard.contract(max_size > 0, "max_size must be positive")
        return setmetatable({ _store = {}, _max = max_size, _count = 0 }, mt)
    end

    function M:put(key, value)
        guard.assert_type(key, "string", "key")
        guard.assert_not_nil(value, "value")
        guard.contract(self._count < self._max, "cache is full")
        if not self._store[key] then
            self._count = self._count + 1
        end
        self._store[key] = value
    end

    function M:get(key)
        guard.assert_type(key, "string", "key")
        return self._store[key]
    end

    setmetatable(M, {
        __call = function(_, ...)
            return M.new(...)
        end,
    })
    return M
end

local function demo_callable_module()
    banner("2. Module with __call (AwesomeWM gears.cache)")
    local Cache = make_cache_module()
    local c1 = Cache.new(10)
    c1:put("host", "localhost")
    io.write('  Via .new():  get("host") = ' .. tostring(c1:get("host")) .. "\n")
    local c2 = Cache(5)
    c2:put("port", "8080")
    io.write('  Via __call:  get("port") = ' .. tostring(c2:get("port")) .. "\n")
    log.info("callable module: __call wraps new() for one-liner require")
end

-- Pattern 3: Module Extending stdlib (APISIX core.table pattern)

local function make_table_ext()
    local M = setmetatable({}, { __index = table })

    function M.is_empty(tbl)
        guard.assert_type(tbl, "table", "tbl")
        local has_entry = next(tbl) ~= nil
        return not has_entry
    end

    function M.keys(tbl)
        guard.assert_type(tbl, "table", "tbl")
        local result = {}
        for k in pairs(tbl) do
            result[#result + 1] = k
        end
        M.sort(result)
        return result
    end

    function M.shallow_copy(tbl)
        guard.assert_type(tbl, "table", "tbl")
        local copy = {}
        for k, v in pairs(tbl) do
            copy[k] = v
        end
        return copy
    end

    return M
end

local function demo_extending_stdlib()
    banner("3. Module Extending stdlib (APISIX core.table)")
    local tbl = make_table_ext()
    local arr = { 3, 1, 4, 1, 5 }
    tbl.sort(arr)
    io.write("  tbl.sort (inherited): " .. tbl.concat(arr, ", ") .. "\n")
    io.write("  tbl.is_empty({}):     " .. tostring(tbl.is_empty({})) .. "\n")
    local data = { host = "localhost", port = 8080 }
    io.write("  tbl.keys(data):       " .. tbl.concat(tbl.keys(data), ", ") .. "\n")
    io.write("  tbl.shallow_copy:     host=" .. tostring(tbl.shallow_copy(data).host) .. "\n")
    log.info("stdlib extension: inherit table.* via __index, add custom methods")
end

-- Pattern 4: Private Constructor (Kong PDK pattern)

local function make_logger_module()
    local M = {}

    local function format_entry(level, msg)
        guard.assert_type(level, "string", "level")
        guard.assert_type(msg, "string", "msg")
        return string_format("[%s] %s", level, msg)
    end

    local function flush_buffer(self)
        local out = {}
        for i = 1, #self._buffer do
            out[#out + 1] = self._buffer[i]
        end
        self._buffer = {}
        return out
    end

    function M.new(name)
        guard.assert_type(name, "string", "name")
        local logger = { _name = name, _buffer = {} }
        function logger:write(level, msg)
            local c = validate.Checker:new()
            c:check_string_not_empty(level, "level")
            c:check_string_not_empty(msg, "msg")
            c:assert()
            self._buffer[#self._buffer + 1] = format_entry(level, self._name .. ": " .. msg)
        end
        function logger:flush()
            return flush_buffer(self)
        end
        function logger:pending()
            return #self._buffer
        end
        return logger
    end

    return M
end

local function demo_private_constructor()
    banner("4. Private Constructor (Kong PDK)")
    local Logger = make_logger_module()
    local lg = Logger.new("auth-service")
    lg:write("INFO", "started")
    lg:write("WARN", "token expiring")
    lg:write("ERR", "refresh failed")
    io.write("  Pending: " .. tostring(lg:pending()) .. "\n")
    local flushed = lg:flush()
    for i = 1, #flushed do
        io.write("  Flushed: " .. flushed[i] .. "\n")
    end
    io.write("  After flush: " .. tostring(lg:pending()) .. " pending\n")
    log.info("private constructor: format_entry hidden via local scope")
end

-- Pattern 5: Hierarchical Module (namespace pattern)

local function make_sdk()
    local M = { _NAME = "app-sdk" }

    M.utils = {}
    function M.utils.slugify(text)
        guard.assert_type(text, "string", "text")
        return text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
    end
    function M.utils.truncate(text, max_len)
        guard.assert_type(text, "string", "text")
        guard.assert_type(max_len, "number", "max_len")
        guard.contract(max_len > 0, "max_len must be positive")
        if #text <= max_len then
            return text
        end
        return text:sub(1, max_len) .. "..."
    end

    M.types = {}
    function M.types.is_string(v)
        return type(v) == "string"
    end
    function M.types.is_positive_int(v)
        return type(v) == "number" and v > 0 and v == math.floor(v)
    end
    function M.types.check_record(record, fields)
        guard.assert_type(record, "table", "record")
        guard.assert_type(fields, "table", "fields")
        local c = validate.Checker:new()
        for i = 1, #fields do
            c:check_not_nil(record[fields[i]], fields[i])
        end
        return c:ok(), c:errors()
    end

    return M
end

local function demo_hierarchical()
    banner("5. Hierarchical Module (namespace pattern)")
    local sdk = make_sdk()
    io.write("  sdk._NAME:              " .. sdk._NAME .. "\n")
    io.write("  utils.slugify:          " .. sdk.utils.slugify("Hello World!") .. "\n")
    io.write("  utils.truncate(6 -> 4): " .. sdk.utils.truncate("abcdef", 4) .. "\n")
    io.write('  types.is_string("y"):   ' .. tostring(sdk.types.is_string("y")) .. "\n")
    io.write("  types.is_positive_int:  " .. tostring(sdk.types.is_positive_int(42)) .. "\n")
    local ok, errs = sdk.types.check_record({ name = "x" }, { "name", "age" })
    io.write("  check_record:           ok=" .. tostring(ok) .. " err=" .. tostring(rawget(errs, 1)) .. "\n")
    log.info("hierarchical: nested namespaces like kong.db, kong.cache")
end

-- Pattern 6: Lazy-Init Module (deferred initialization)

local function make_database()
    local M = {}
    local _initialized = false
    local _config = nil

    function M.init(config)
        guard.assert_type(config, "table", "config")
        local c = validate.Checker:new()
        c:check_string_not_empty(config.host, "config.host")
        c:check_type(config.port, "number", "config.port")
        c:check_range(config.port, 1, 65535, "config.port")
        c:assert()
        _config = { host = config.host, port = config.port, name = config.name or "default" }
        _initialized = true
        log.info("db initialized: %s:%d/%s", _config.host, _config.port, _config.name)
    end

    function M.is_initialized()
        return _initialized
    end

    function M.query(sql)
        guard.contract(_initialized, "database not initialized: call init() first")
        guard.assert_type(sql, "string", "sql")
        return string_format("result from %s:%d/%s: [%s]", _config.host, _config.port, _config.name, sql)
    end

    function M.connection_info()
        guard.contract(_initialized, "database not initialized: call init() first")
        return string_format("%s:%d/%s", _config.host, _config.port, _config.name)
    end

    return M
end

local function demo_lazy_init()
    banner("6. Lazy-Init Module (deferred initialization)")
    local db = make_database()
    io.write("  Before init: initialized=" .. tostring(db.is_initialized()) .. "\n")
    local ok, err = pcall(db.query, "SELECT 1")
    io.write("  query before init: ok=" .. tostring(ok) .. "\n")
    io.write("  Error: " .. tostring(err) .. "\n")
    db.init({ host = "db.local", port = 5432, name = "app_prod" })
    io.write("  After init:  initialized=" .. tostring(db.is_initialized()) .. "\n")
    io.write("  connection_info = " .. db.connection_info() .. "\n")
    io.write('  query("SELECT 1") = ' .. db.query("SELECT 1") .. "\n")
    log.info("lazy-init: guard.contract enforces initialization order")
end

-- Pattern 7: Module Versioning (metadata pattern)

local function make_versioned()
    local M = { _VERSION = "2.3.1", _DESCRIPTION = "Versioned utility module", _LICENSE = "MIT" }

    local function parse_version(version)
        guard.assert_type(version, "string", "version")
        local maj, min, pat = version:match("^(%d+)%.(%d+)%.(%d+)$")
        guard.contract(maj ~= nil, "invalid version: expected X.Y.Z, got " .. version)
        return tonumber(maj), tonumber(min), tonumber(pat)
    end

    function M.check_version(required)
        guard.assert_type(required, "string", "required")
        local rj, rn, rp = parse_version(required)
        local cj, cn, cp = parse_version(M._VERSION)
        if cj ~= rj then
            return false, string_format("major mismatch: need %d, have %d", rj, cj)
        end
        if cn < rn then
            return false, string_format("minor too old: need %d.%d+, have %s", rj, rn, M._VERSION)
        end
        if cn == rn and cp < rp then
            return false, string_format("patch too old: need %s+, have %s", required, M._VERSION)
        end
        return true, nil
    end

    function M.version_info()
        return string_format("%s (%s) [%s]", M._VERSION, M._DESCRIPTION, M._LICENSE)
    end

    return M
end

local function demo_versioning()
    banner("7. Module Versioning (metadata pattern)")
    local mod = make_versioned()
    io.write("  _VERSION=" .. mod._VERSION .. "  _LICENSE=" .. mod._LICENSE .. "\n")
    io.write("  version_info: " .. mod.version_info() .. "\n")
    local ok, err = mod.check_version("2.3.0")
    io.write('  check("2.3.0"): ok=' .. tostring(ok) .. " err=" .. tostring(err) .. "\n")
    ok, err = mod.check_version("2.3.1")
    io.write('  check("2.3.1"): ok=' .. tostring(ok) .. " err=" .. tostring(err) .. "\n")
    ok, err = mod.check_version("2.4.0")
    io.write('  check("2.4.0"): ok=' .. tostring(ok) .. " err=" .. tostring(err) .. "\n")
    ok, err = mod.check_version("3.0.0")
    io.write('  check("3.0.0"): ok=' .. tostring(ok) .. " err=" .. tostring(err) .. "\n")
    log.info("versioning: semantic version checks for compatibility")
end

-- Main

local function main(_args)
    io.write("Module Definition Idioms in Lua 5.1\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Seven patterns from APISIX, AwesomeWM, Kong, xmake,\n")
    io.write("luasocket, and lpeg — with safe-lua defensive checks.\n")

    demo_return_table()
    demo_callable_module()
    demo_extending_stdlib()
    demo_private_constructor()
    demo_hierarchical()
    demo_lazy_init()
    demo_versioning()

    io.write("\n" .. string_rep("=", 60) .. "\n")
    log.info("all seven module patterns demonstrated successfully")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
