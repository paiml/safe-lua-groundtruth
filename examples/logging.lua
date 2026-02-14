#!/usr/bin/env lua5.1
--[[
  logging.lua — Example: structured logging with safe.log.
  Demonstrates level gating, child loggers, output injection,
  and custom timestamp formatting.

  Usage: lua5.1 examples/logging.lua [debug|info|warn|error]
]]

package.path = "lib/?.lua;" .. package.path

local log = require("safe.log")
local guard = require("safe.guard")
local validate = require("safe.validate")

local string_format = string.format
local os_date = os.date
local os_clock = os.clock

-- Level name to constant mapping
local LEVELS = {
    debug = log.DEBUG,
    info = log.INFO,
    warn = log.WARN,
    error = log.ERROR,
}

local function main(args)
    -- Parse optional log level argument
    local level_name = args[1] or "debug"
    local ok, _err = validate.check_one_of(level_name, { "debug", "info", "warn", "error" }, "level")
    if not ok then
        io.stderr:write("Unknown level: " .. level_name .. "\n")
        io.stderr:write("Usage: lua5.1 examples/logging.lua [debug|info|warn|error]\n")
        return 1
    end

    -- ----------------------------------------------------------------
    -- 1. Basic level-gated logging
    -- ----------------------------------------------------------------
    io.write("=== Basic Level Gating ===\n")
    log.set_level(LEVELS[level_name])
    log.set_context(nil)

    log.debug("this is a debug message (verbose)")
    log.info("server starting on port %d", 8080)
    log.warn("connection pool at %d%% capacity", 85)
    log.error("failed to connect to %s:%d", "db.example.com", 5432)

    -- ----------------------------------------------------------------
    -- 2. Child loggers with context
    -- ----------------------------------------------------------------
    io.write("\n=== Child Loggers ===\n")
    log.set_level(log.DEBUG)

    local db_log = log.with_context("database")
    local http_log = log.with_context("http")
    local cache_log = log.with_context("cache")

    db_log.info("connection pool initialized (max=%d)", 10)
    http_log.info("listening on %s:%d", "0.0.0.0", 8080)
    cache_log.debug("LRU size=%d, ttl=%ds", 1000, 300)

    -- Simulate a request lifecycle
    http_log.debug("GET /api/users")
    cache_log.debug("cache miss for key=%s", "users:list")
    db_log.debug("SELECT * FROM users LIMIT 50")
    db_log.info("query returned %d rows in %.1fms", 42, 3.7)
    cache_log.info("cached key=%s ttl=%ds", "users:list", 300)
    http_log.info("200 OK (%.1fms)", 5.2)

    -- ----------------------------------------------------------------
    -- 3. Custom output handler (JSON-style)
    -- ----------------------------------------------------------------
    io.write("\n=== JSON Output Handler ===\n")
    log.set_context("app")

    -- Save current behavior by setting a new handler
    log.set_output(function(msg)
        -- Parse the structured message and re-emit as JSON-like
        local ts, level, ctx, body = msg:match("^%[(.-)%] %[(.-)%] %[(.-)%] (.+)$")
        if ts and level and ctx and body then
            io.write(string_format('{"ts":"%s","level":"%s","ctx":"%s","msg":"%s"}\n', ts, level, ctx, body))
        else
            io.write(msg .. "\n")
        end
    end)

    log.info("application started")
    log.warn("deprecated API called: /v1/users")
    log.error("unhandled exception in request handler")

    -- Restore default output
    log.set_output(function(msg)
        io.write(msg .. "\n")
    end)

    -- ----------------------------------------------------------------
    -- 4. Custom timestamp (monotonic clock)
    -- ----------------------------------------------------------------
    io.write("\n=== Custom Timestamp (Elapsed) ===\n")
    log.set_context("bench")
    local start = os_clock()

    log.set_timestamp(function()
        return string_format("+%.4fs", os_clock() - start)
    end)

    log.info("benchmark starting")
    -- Simulate work
    local sum = 0
    for i = 1, 1e6 do
        sum = sum + i
    end
    guard.contract(sum > 0, "sum must be positive")
    log.info("computed sum of 1..1M = %g", sum)
    log.info("benchmark complete")

    -- Restore default timestamp
    log.set_timestamp(function()
        return os_date("%Y-%m-%dT%H:%M:%S")
    end)
    log.set_context(nil)

    return 0
end

os.exit(main(arg))
