#!/usr/bin/env lua5.1
--[[
  cli_tool.lua — Example: building a safe CLI tool.
  Demonstrates guard contracts, input validation, and safe shell execution.

  Usage:
    lua5.1 examples/cli_tool.lua search <pattern> <directory>
    lua5.1 examples/cli_tool.lua count <directory>
    lua5.1 examples/cli_tool.lua --help
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local shell = require("safe.shell")
local log = require("safe.log")

local table_concat = table.concat
local tostring = tostring

-- Wire logging to stderr so stdout stays clean for tool output
log.set_level(log.DEBUG)
log.set_output(function(msg)
    io.stderr:write(msg .. "\n")
end)
log.set_context("cli")

-- Frozen command registry — no accidental mutations
local COMMANDS = guard.enum({ "search", "count", "help" })

local function usage()
    io.write(table_concat({
        "Usage: lua5.1 examples/cli_tool.lua <command> [args...]",
        "",
        "Commands:",
        "  search <pattern> <dir>   Search files for a pattern",
        "  count <dir>              Count files in a directory",
        "  --help                   Show this message",
        "",
    }, "\n"))
end

local function cmd_search(pattern, directory)
    -- Validate inputs with error accumulation
    local c = validate.Checker:new()
    c:check_string_not_empty(pattern, "pattern")
    c:check_string_not_empty(directory, "directory")
    if not c:ok() then
        io.stderr:write("Error: " .. table_concat(c:errors(), "; ") .. "\n")
        return 1
    end

    log.debug("searching for %q in %s", pattern, directory)

    local ok, output = shell.capture("grep", { "-rn", "--color=never", pattern, directory })
    if not ok then
        log.warn("grep returned non-zero or failed")
        io.write("No matches found.\n")
        return 1
    end

    io.write(tostring(output))
    return 0
end

local function cmd_count(directory)
    local ok, err = validate.check_string_not_empty(directory, "directory")
    if not ok then
        io.stderr:write("Error: " .. err .. "\n")
        return 1
    end

    log.debug("counting files in %s", directory)

    -- Safe shell: arguments are escaped, never interpolated
    local exec_ok, output = shell.capture("find", { directory, "-type", "f" })
    if not exec_ok then
        log.error("find command failed")
        return 1
    end

    -- Count lines in output
    local count = 0
    local output_str = tostring(output)
    for _ in output_str:gmatch("[^\n]+") do
        count = count + 1
    end
    io.write(count .. " files\n")
    return 0
end

-- Main dispatch
local function main(args)
    if #args == 0 or args[1] == "--help" or args[1] == COMMANDS.help then
        usage()
        return 0
    end

    local command = args[1]

    -- Guard: command must be a known enum value
    local ok, _err = validate.check_one_of(command, { "search", "count" }, "command")
    if not ok then
        io.stderr:write("Unknown command: " .. tostring(command) .. "\n")
        usage()
        return 1
    end

    log.info("running command: %s", command)

    if command == COMMANDS.search then
        return cmd_search(args[2], args[3])
    elseif command == COMMANDS.count then
        return cmd_count(args[2])
    end

    return 1
end

local exit_code = main(arg)
os.exit(exit_code)
