--[[
  test_helpers.lua — Testing utilities for safe-lua-groundtruth.
  Mock factories, temp files, assertion helpers.
]]

local M = {}

local type = type
local tostring = tostring
local os_tmpname = os.tmpname
local os_remove = os.remove
local io_open = io.open

--- Create a mock executor that returns pre-configured responses.
--- @param responses table array of {ok, code} pairs
--- @return function executor, table calls tracker
function M.mock_executor(responses)
    local calls = {}
    local idx = 0
    local function executor(cmd)
        idx = idx + 1
        calls[#calls + 1] = cmd
        local resp = responses[idx] or { false, 1 }
        return resp[1], resp[2]
    end
    return executor, calls
end

--- Create a mock popen that returns pre-configured outputs.
--- @param outputs table array of {ok, output} pairs
--- @return function popen, table calls tracker
function M.mock_popen(outputs)
    local calls = {}
    local idx = 0
    local function popen(cmd)
        idx = idx + 1
        calls[#calls + 1] = cmd
        local resp = outputs[idx] or { false, nil }
        return resp[1], resp[2]
    end
    return popen, calls
end

--- Capture io.write output during function execution.
--- @param fn function to execute
--- @return string captured output
function M.capture_output(fn)
    local captured = {}
    local orig_write = io.write
    -- selene: allow(incorrect_standard_library_use)
    io.write = function(...)
        for i = 1, select("#", ...) do
            captured[#captured + 1] = tostring(select(i, ...))
        end
    end
    local ok, err = pcall(fn)
    -- selene: allow(incorrect_standard_library_use)
    io.write = orig_write
    if not ok then
        error(err, 2)
    end
    return table.concat(captured)
end

--- Assert that a function throws an error matching a pattern.
--- @param fn function
--- @param pattern string Lua pattern to match
function M.assert_errors(fn, pattern)
    local ok, err = pcall(fn)
    if ok then
        error("expected function to throw, but it did not", 2)
    end
    if pattern and not tostring(err):find(pattern) then
        error("error did not match pattern: " .. tostring(pattern) .. "\ngot: " .. tostring(err), 2)
    end
end

--- Assert that a function does not throw.
--- @param fn function
function M.assert_no_errors(fn)
    local ok, err = pcall(fn)
    if not ok then
        error("expected no error, got: " .. tostring(err), 2)
    end
end

--- Create a temp file, call fn(path), then clean up.
--- @param content string file content
--- @param fn function receives temp file path
function M.with_temp_file(content, fn)
    local path = os_tmpname()
    local f = io_open(path, "w")
    if not f then
        error("failed to create temp file: " .. path, 2)
    end
    f:write(content)
    f:close()
    local ok, err = pcall(fn, path)
    os_remove(path)
    if not ok then
        error(err, 2)
    end
end

--- Deep table equality comparison.
--- @param a any
--- @param b any
--- @return boolean
function M.table_eq(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for k, v in pairs(a) do
        if not M.table_eq(v, b[k]) then
            return false
        end
    end
    for k, _ in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

return M
