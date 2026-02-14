#!/usr/bin/env lua5.1
--[[
  file_io.lua — Example: safe file I/O patterns.
  Demonstrates file reading, writing, existence checks, temp files,
  and resource cleanup. Patterns from resolve-pipeline: read_file,
  write_file, io.open checks, seek for file size.

  Usage: lua5.1 examples/file_io.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")
local test_helpers = require("safe.test_helpers")

local string_format = string.format
local string_rep = string.rep
local tostring = tostring
local io_open = io.open
local os_tmpname = os.tmpname
local os_remove = os.remove
local pcall = pcall

log.set_level(log.INFO)
log.set_context("file_io")

-- ----------------------------------------------------------------
-- Safe file I/O functions (resolve-pipeline patterns)
-- ----------------------------------------------------------------

--- Read an entire file safely. Returns nil on failure.
--- @param path string file path
--- @return string|nil content
--- @return string|nil error
local function read_file(path)
    local ok, err = validate.check_string_not_empty(path, "path")
    if not ok then
        return nil, err
    end

    local f = io_open(path, "r")
    if not f then
        return nil, string_format("cannot open file: %s", path)
    end

    local content = f:read("*a")
    f:close()
    return content, nil
end

--- Write content to a file safely. Returns false on failure.
--- @param path string file path
--- @param content string content to write
--- @return boolean ok
--- @return string|nil error
local function write_file(path, content)
    local c = validate.Checker.new()
    c:check_string_not_empty(path, "path")
    c:check_type(content, "string", "content")
    if not c:ok() then
        return false, c:errors()[1]
    end

    local f = io_open(path, "w")
    if not f then
        return false, string_format("cannot open file for writing: %s", path)
    end

    f:write(content)
    f:close()
    return true, nil
end

--- Check if a file exists by attempting to open it.
--- @param path string file path
--- @return boolean exists
local function file_exists(path)
    if type(path) ~= "string" then
        return false
    end
    local f = io_open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

--- Get file size via seek("end").
--- @param path string file path
--- @return number|nil size in bytes
--- @return string|nil error
local function file_size(path)
    local ok, err = validate.check_string_not_empty(path, "path")
    if not ok then
        return nil, err
    end

    local f = io_open(path, "r")
    if not f then
        return nil, string_format("cannot open file: %s", path)
    end

    local size = f:seek("end")
    f:close()
    return size, nil
end

--- Process a file with guaranteed cleanup (RAII-like pattern).
--- @param path string file path
--- @param mode string open mode
--- @param fn function receives file handle, returns result
--- @return boolean ok
--- @return any result_or_error
local function with_file(path, mode, fn)
    local ok, err = validate.check_string_not_empty(path, "path")
    if not ok then
        return false, err
    end

    local f = io_open(path, mode)
    if not f then
        return false, string_format("cannot open file: %s", path)
    end

    local call_ok, result = pcall(fn, f)
    f:close()

    if not call_ok then
        return false, result
    end
    return true, result
end

--- Count lines in a file via gmatch iteration.
--- @param content string file content
--- @return number line count
local function count_lines(content)
    guard.assert_type(content, "string", "content")
    local count = 0
    for _ in content:gmatch("[^\n]*\n") do
        count = count + 1
    end
    -- Count last line if it doesn't end with newline
    if content:sub(-1) ~= "\n" and #content > 0 then
        count = count + 1
    end
    return count
end

local function main(_args)
    io.write("Safe File I/O Patterns\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- 1. Write and read back
    io.write("1. Write & Read\n")
    io.write(string_rep("-", 50) .. "\n")
    local tmp = os_tmpname()
    local test_content = "line 1\nline 2\nline 3\n"

    local w_ok, w_err = write_file(tmp, test_content)
    io.write(string_format("  write ok: %s\n", tostring(w_ok)))
    guard.contract(w_ok, tostring(w_err))

    local content, r_err = read_file(tmp)
    io.write(string_format("  read ok:  %s\n", tostring(content ~= nil)))
    guard.contract(content ~= nil, tostring(r_err))
    guard.contract(content == test_content, "content must round-trip")
    io.write(string_format("  lines:    %d\n", count_lines(content)))

    -- 2. File existence checks
    io.write("\n2. Existence Checks\n")
    io.write(string_rep("-", 50) .. "\n")
    io.write(string_format("  temp file exists: %s\n", tostring(file_exists(tmp))))
    io.write(string_format("  missing exists:   %s\n", tostring(file_exists("/nonexistent/file.txt"))))
    io.write(string_format("  nil exists:       %s\n", tostring(file_exists(nil))))

    -- 3. File size via seek
    io.write("\n3. File Size (seek pattern)\n")
    io.write(string_rep("-", 50) .. "\n")
    local size, size_err = file_size(tmp)
    io.write(string_format("  size: %s bytes\n", tostring(size)))
    guard.contract(size ~= nil, tostring(size_err))
    guard.contract(size == #test_content, "size must match content length")

    -- 4. with_file pattern (RAII cleanup)
    io.write("\n4. with_file (RAII Cleanup)\n")
    io.write(string_rep("-", 50) .. "\n")

    -- Read via with_file
    local wf_ok, wf_result = with_file(tmp, "r", function(f)
        return f:read("*a")
    end)
    io.write(string_format("  read via with_file: %s\n", tostring(wf_ok)))
    guard.contract(wf_ok, tostring(wf_result))
    guard.contract(wf_result == test_content, "with_file must read correctly")

    -- Error in callback — file handle still closed
    local err_ok, _err_msg = with_file(tmp, "r", function(_f)
        error("simulated processing error")
    end)
    io.write(string_format("  error caught:       %s\n", tostring(not err_ok)))
    io.write(string_format("  cleanup ran:        true (file handle closed)\n"))

    -- 5. test_helpers.with_temp_file
    io.write("\n5. test_helpers.with_temp_file\n")
    io.write(string_rep("-", 50) .. "\n")
    test_helpers.with_temp_file("hello from temp\n", function(path)
        io.write(string_format("  temp path: %s\n", path))
        io.write(string_format("  exists:    %s\n", tostring(file_exists(path))))
        local c = read_file(path)
        io.write(string_format("  content:   %s", tostring(c)))
    end)
    io.write("  (temp file auto-cleaned)\n")

    -- 6. Error handling for bad inputs
    io.write("\n6. Error Handling\n")
    io.write(string_rep("-", 50) .. "\n")
    local _c1, e1 = read_file("")
    io.write(string_format("  read empty path:  %s\n", tostring(e1)))
    local _c2, e2 = read_file("/nonexistent/file.txt")
    io.write(string_format("  read missing:     %s\n", tostring(e2)))
    local _w2_ok, w2_err = write_file("", "data")
    io.write(string_format("  write empty path: %s\n", tostring(w2_err)))

    -- Cleanup
    os_remove(tmp)

    io.write("\n")
    log.info("file I/O demo complete")
    return 0
end

os.exit(main(arg))
