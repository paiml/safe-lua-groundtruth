#!/usr/bin/env lua5.1
--[[
  serialization.lua — Example: encode/decode and data interchange.
  Demonstrates Lua table serialization with cycle detection, safe
  deserialization via loadstring + setfenv sandbox, minimal JSON
  encoding, and round-trip validation.

  Patterns from KOReader dump/serialize, xmake serialize.lua,
  APISIX JSON patterns, lite-xl dkjson.lua.

  Usage: lua5.1 examples/serialization.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local type = type
local pairs = pairs
local tostring = tostring
local string_format = string.format
local string_rep = string.rep
local string_gsub = string.gsub
local string_sub = string.sub
local string_byte = string.byte
local table_insert = table.insert
local table_concat = table.concat
local math_huge = math.huge

log.set_level(log.INFO)
log.set_context("serialization")

local function banner(title)
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("Section: %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- Helper: detect whether a table is an array (consecutive integer
-- keys starting at 1) vs a hash/mixed table.
-- Mirrors the heuristic used by KOReader dump.lua and dkjson.
-- ================================================================

--- Check if a table is a pure array.
--- @param tbl table
--- @return boolean
local function is_array(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    -- An array has exactly #tbl pairs, all at integer keys 1..#tbl
    return count == #tbl
end

-- ================================================================
-- Pattern 1: Lua table serializer
--
-- Inspired by KOReader dump.lua serialize and xmake serialize.lua.
-- Produces valid Lua source that can be loaded back with loadstring.
-- ================================================================

--- Escape a string for Lua source representation.
--- @param s string raw string
--- @return string escaped string with surrounding quotes
local function escape_lua_string(s)
    local escaped = string_gsub(s, ".", function(c)
        local b = string_byte(c)
        if c == "\\" then
            return "\\\\"
        elseif c == '"' then
            return '\\"'
        elseif c == "\n" then
            return "\\n"
        elseif c == "\t" then
            return "\\t"
        elseif c == "\r" then
            return "\\r"
        elseif b < 32 or b > 126 then
            return string_format("\\%03d", b)
        else
            return c
        end
    end)
    return '"' .. escaped .. '"'
end

--- Serialize a number to Lua source, handling NaN and infinity.
--- @param val number
--- @return string
local function ser_number(val)
    if val ~= val then
        return "0/0" -- NaN
    elseif val == math_huge then
        return "1/0"
    elseif val == -math_huge then
        return "-1/0"
    end
    return tostring(val)
end

--- Format a table key for Lua source.
--- @param k any key value
--- @param ser_fn function recursive serializer
--- @param depth number current depth
--- @return string formatted key
local function format_key(k, ser_fn, depth)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
        return k
    end
    return "[" .. ser_fn(k, depth + 1) .. "]"
end

--- Collect serialized parts from a table (array or hash).
--- @param val table table to serialize
--- @param pad string indentation padding
--- @param ser_fn function recursive serializer
--- @param depth number current depth
--- @return table parts array of serialized entries
local function collect_parts(val, pad, ser_fn, depth)
    local parts = {}
    if is_array(val) then
        for i = 1, #val do
            local entry = ser_fn(val[i], depth + 1)
            table_insert(parts, pad .. entry)
        end
    else
        for k, v in pairs(val) do
            local entry = format_key(k, ser_fn, depth) .. " = " .. ser_fn(v, depth + 1)
            table_insert(parts, pad .. entry)
        end
    end
    return parts
end

--- Join parts into a table literal string.
--- @param parts table array of serialized entries
--- @param sep string separator between entries
--- @param nl string newline string ("" or "\n")
--- @param closing_pad string closing brace indentation
--- @return string table literal
local function join_table_parts(parts, sep, nl, closing_pad)
    if #parts == 0 then
        return "{}"
    end
    return "{" .. nl .. table_concat(parts, sep .. nl) .. nl .. closing_pad .. "}"
end

--- Serialize a Lua value to valid Lua source.
--- @param value any value to serialize
--- @param indent number|nil indentation level (0 = compact, >0 = pretty)
--- @return string Lua source representation
local function serialize(value, indent)
    indent = indent or 0
    local seen = {}

    local function ser(val, depth)
        local t = type(val)

        if val == nil then
            return "nil"
        elseif t == "boolean" then
            return tostring(val)
        elseif t == "number" then
            return ser_number(val)
        elseif t == "string" then
            return escape_lua_string(val)
        elseif t == "table" then
            guard.contract(not seen[val], "cycle detected during serialization")
            seen[val] = true

            local pad = indent > 0 and string_rep(" ", indent * (depth + 1)) or ""
            local sep = indent > 0 and "," or ", "
            local nl = indent > 0 and "\n" or ""
            local closing_pad = indent > 0 and string_rep(" ", indent * depth) or ""

            local parts = collect_parts(val, pad, ser, depth)
            seen[val] = nil -- allow table to appear in other branches
            return join_table_parts(parts, sep, nl, closing_pad)
        else
            guard.contract(false, "unsupported type for serialization: " .. t)
        end
    end

    return ser(value, 0)
end

-- ================================================================
-- Pattern 2: Pretty-print with "return" prefix
-- ================================================================

--- Pretty-print a Lua value as a loadable chunk.
--- @param value any
--- @return string valid Lua chunk "return <value>"
local function pretty_print(value)
    return "return " .. serialize(value, 2)
end

-- ================================================================
-- Pattern 3: Safe deserialization via loadstring + setfenv sandbox
--
-- Inspired by KOReader unserialize and xmake deserialize.lua.
-- Uses setfenv to create an empty sandbox — the loaded chunk
-- cannot access any global functions (os.execute, io, etc).
-- ================================================================

--- Safely deserialize a Lua source string.
--- @param str string Lua source (e.g., "return {1, 2, 3}")
--- @return any deserialized value
local function safe_deserialize(str)
    guard.assert_type(str, "string", "str")
    local chunk, err = loadstring(str) -- luacheck: ignore 113
    guard.contract(chunk ~= nil, "loadstring failed: " .. tostring(err))
    -- Sandbox: setfenv to empty table blocks all global access
    setfenv(chunk, {}) -- luacheck: ignore 113
    log.info("deserializing chunk (%d bytes)", #str)
    local ok, result = pcall(chunk)
    guard.contract(ok, "deserialization error: " .. tostring(result))
    return result
end

-- ================================================================
-- Pattern 4: Minimal JSON-like encoder
--
-- Inspired by APISIX core.json and lite-xl dkjson.lua.
-- Handles nil, boolean, number, string, arrays, and objects.
-- ================================================================

--- Escape a string for JSON representation.
--- @param s string raw string
--- @return string JSON-escaped string with surrounding quotes
local function escape_json_string(s)
    local escaped = string_gsub(s, ".", function(c)
        if c == '"' then
            return '\\"'
        elseif c == "\\" then
            return "\\\\"
        elseif c == "\n" then
            return "\\n"
        elseif c == "\t" then
            return "\\t"
        elseif c == "\r" then
            return "\\r"
        elseif c == "\b" then
            return "\\b"
        elseif c == "\f" then
            return "\\f"
        elseif c == "/" then
            return "\\/"
        else
            local b = string_byte(c)
            if b < 32 then
                return string_format("\\u%04x", b)
            end
            return c
        end
    end)
    return '"' .. escaped .. '"'
end

--- Encode a Lua value as JSON.
--- @param value any value to encode
--- @return string JSON string
local function json_encode(value)
    local seen = {}

    local function enc(val)
        if val == nil then
            return "null"
        end

        local t = type(val)

        if t == "boolean" then
            return tostring(val)
        elseif t == "number" then
            guard.contract(val == val, "cannot encode NaN as JSON")
            guard.contract(val ~= math_huge and val ~= -math_huge, "cannot encode Infinity as JSON")
            return tostring(val)
        elseif t == "string" then
            return escape_json_string(val)
        elseif t == "table" then
            guard.contract(not seen[val], "cycle detected during JSON encoding")
            seen[val] = true

            local parts = {}
            if is_array(val) then
                -- JSON array: [v1, v2, v3]
                for i = 1, #val do
                    table_insert(parts, enc(val[i]))
                end
                seen[val] = nil
                return "[" .. table_concat(parts, ", ") .. "]"
            else
                -- JSON object: {"key": value}
                for k, v in pairs(val) do
                    guard.contract(type(k) == "string", "JSON object keys must be strings, got " .. type(k))
                    table_insert(parts, escape_json_string(k) .. ": " .. enc(v))
                end
                seen[val] = nil
                return "{" .. table_concat(parts, ", ") .. "}"
            end
        else
            guard.contract(false, "unsupported type for JSON encoding: " .. t)
        end
    end

    return enc(value)
end

-- ================================================================
-- Pattern 5: Deep equality for round-trip validation
-- ================================================================

--- Deep-compare two values for structural equality.
--- @param a any
--- @param b any
--- @return boolean
local function deep_equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    -- Compare all keys in a
    for k, v in pairs(a) do
        if not deep_equal(v, b[k]) then
            return false
        end
    end
    -- Check b has no extra keys
    for k, _ in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

-- ================================================================
-- Demo functions
-- ================================================================

local function demo_lua_serialize()
    banner("1. Lua Table Serializer")

    local data = {
        name = "safe-lua",
        version = 1,
        enabled = true,
        tags = { "lua", "safety", "patterns" },
        config = {
            timeout = 30,
            retries = 3,
            verbose = false,
        },
    }

    log.info("serializing complex nested table")
    local compact = serialize(data)
    io.write("  Compact:\n")
    io.write("    " .. compact .. "\n")

    local pretty = pretty_print(data)
    io.write("  Pretty (return prefix):\n")
    for line in pretty:gmatch("[^\n]+") do
        io.write("    " .. line .. "\n")
    end

    -- Demonstrate special values
    io.write("  Special values:\n")
    io.write(string_format("    nil:    %s\n", serialize(nil)))
    io.write(string_format("    true:   %s\n", serialize(true)))
    io.write(string_format("    42:     %s\n", serialize(42)))
    io.write(string_format("    string: %s\n", serialize("hello\nworld")))
    io.write(string_format("    empty:  %s\n", serialize({})))

    log.info("serialization complete")
end

local function demo_cycle_detection()
    banner("2. Cycle Detection")

    local a = { name = "node_a" }
    local b = { name = "node_b" }
    a.ref = b
    b.ref = a -- cycle: a -> b -> a

    log.info("attempting to serialize cyclic table")
    local ok, err = pcall(serialize, a)
    io.write(string_format("  Cyclic table serialized? %s\n", tostring(ok)))
    if not ok then
        io.write(string_format("  Error: %s\n", tostring(err)))
    end

    -- Non-cyclic shared reference should work
    local shared = { x = 10 }
    local parent = { left = shared, right = shared }
    log.info("serializing table with shared (non-cyclic) references")
    local result = serialize(parent, 2)
    io.write("  Shared reference (non-cyclic) works:\n")
    for line in result:gmatch("[^\n]+") do
        io.write("    " .. line .. "\n")
    end
end

local function demo_safe_deserialize()
    banner("3. Safe Deserialization (setfenv sandbox)")

    -- Valid deserialization
    local source = 'return {name = "test", values = {1, 2, 3}, active = true}'
    log.info("deserializing valid source")
    local data = safe_deserialize(source)
    io.write(string_format("  Deserialized name:   %s\n", tostring(data.name)))
    io.write(string_format("  Deserialized values: %d items\n", #data.values))
    io.write(string_format("  Deserialized active: %s\n", tostring(data.active)))

    -- Sandbox blocks global access
    log.info("testing sandbox blocks os.execute")
    local malicious = 'return os.execute("echo pwned")'
    local ok, err = pcall(safe_deserialize, malicious)
    io.write(string_format("  Malicious chunk ran? %s\n", tostring(ok)))
    if not ok then
        io.write(string_format("  Blocked: %s\n", string_sub(tostring(err), 1, 80)))
    end

    -- Sandbox blocks io access too
    log.info("testing sandbox blocks io.open")
    local io_attack = 'return io.open("/etc/passwd")'
    local io_ok, io_err = pcall(safe_deserialize, io_attack)
    io.write(string_format("  IO access ran?       %s\n", tostring(io_ok)))
    if not io_ok then
        io.write(string_format("  Blocked: %s\n", string_sub(tostring(io_err), 1, 80)))
    end

    -- Invalid syntax
    log.info("testing invalid syntax rejection")
    local bad_syntax = "return {{{invalid"
    local syn_ok, syn_err = pcall(safe_deserialize, bad_syntax)
    io.write(string_format("  Bad syntax loaded?   %s\n", tostring(syn_ok)))
    if not syn_ok then
        io.write(string_format("  Rejected: %s\n", string_sub(tostring(syn_err), 1, 80)))
    end
end

local function demo_json_encode()
    banner("4. JSON Encoding")

    log.info("encoding various Lua values to JSON")

    -- Primitives
    io.write("  Primitives:\n")
    io.write(string_format("    nil:     %s\n", json_encode(nil)))
    io.write(string_format("    true:    %s\n", json_encode(true)))
    io.write(string_format("    false:   %s\n", json_encode(false)))
    io.write(string_format("    42:      %s\n", json_encode(42)))
    io.write(string_format("    3.14:    %s\n", json_encode(3.14)))
    io.write(string_format("    string:  %s\n", json_encode("hello\tworld")))

    -- Array
    local arr = { "lua", "python", "rust" }
    io.write(string_format("  Array:     %s\n", json_encode(arr)))

    -- Object
    local obj = { name = "safe-lua", version = "1.0", stable = true }
    io.write(string_format("  Object:    %s\n", json_encode(obj)))

    -- Nested
    local nested = {
        users = {
            { id = 1, name = "Alice", active = true },
            { id = 2, name = "Bob", active = false },
        },
        count = 2,
    }
    io.write(string_format("  Nested:    %s\n", json_encode(nested)))

    -- Unsupported type
    log.info("testing unsupported type rejection")
    local fn_ok, fn_err = pcall(json_encode, function() end)
    io.write(string_format("  Function encoded? %s\n", tostring(fn_ok)))
    if not fn_ok then
        io.write(string_format("  Rejected: %s\n", string_sub(tostring(fn_err), 1, 80)))
    end
end

local function demo_round_trip()
    banner("5. Round-Trip Validation")

    local original = {
        project = "safe-lua-groundtruth",
        version = 2,
        features = { "guard", "validate", "log", "perf", "freeze", "concat" },
        settings = {
            coverage_min = 95,
            lint_warnings = 0,
            frozen = true,
        },
        empty = {},
    }

    -- Serialize
    log.info("serializing for round-trip")
    local source = pretty_print(original)
    io.write("  Serialized:\n")
    for line in source:gmatch("[^\n]+") do
        io.write("    " .. line .. "\n")
    end

    -- Deserialize
    log.info("deserializing round-trip data")
    local restored = safe_deserialize(source)

    -- Validate with Checker
    local c = validate.Checker:new()
    c:check_type(restored, "table", "restored")
    c:check_string_not_empty(restored.project, "project")
    c:check_type(restored.version, "number", "version")
    c:check_type(restored.features, "table", "features")
    c:check_type(restored.settings, "table", "settings")
    c:assert()

    -- Deep equality check
    local equal = deep_equal(original, restored)
    io.write(string_format("  Round-trip equal? %s\n", tostring(equal)))
    guard.contract(equal, "round-trip must preserve data")

    -- Spot checks
    io.write(string_format("  project:      %s\n", restored.project))
    io.write(string_format("  version:      %s\n", tostring(restored.version)))
    io.write(string_format("  features:     %d items\n", #restored.features))
    io.write(string_format("  coverage_min: %s\n", tostring(restored.settings.coverage_min)))
    io.write(string_format("  empty table:  %d keys\n", #restored.empty))

    log.info("round-trip validation passed")
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("Serialization Patterns\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Encode/decode and data interchange from KOReader,\n")
    io.write("xmake, APISIX, and lite-xl — with safe-lua\n")
    io.write("defensive validation.\n")

    demo_lua_serialize()
    demo_cycle_detection()
    demo_safe_deserialize()
    demo_json_encode()
    demo_round_trip()

    io.write("\n" .. string_rep("=", 60) .. "\n")
    io.write("Patterns demonstrated:\n")
    io.write("  Lua table serializer     (cycle detection, escaping)\n")
    io.write("  Pretty-print             (return prefix, indent)\n")
    io.write("  Safe deserialization      (setfenv sandbox)\n")
    io.write("  JSON encoding            (type dispatch, escaping)\n")
    io.write("  Round-trip validation     (serialize + deserialize)\n")
    io.write(string_rep("=", 60) .. "\n")
    log.info("all serialization patterns demonstrated successfully")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
