# safe.test_helpers

Testing utilities: mock factories, temp files, output capture, and assertion helpers.

```lua
local helpers = require("safe.test_helpers")
```

## Source

```lua
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

--- Deep table equality comparison with cycle detection.
--- @param a any
--- @param b any
--- @param seen table|nil (internal) visited pairs for cycle detection
--- @return boolean
function M.table_eq(a, b, seen)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    if a == b then
        return true
    end
    seen = seen or {}
    if seen[a] and seen[a][b] then
        return true
    end
    if not seen[a] then
        seen[a] = {}
    end
    seen[a][b] = true
    for k, v in pairs(a) do
        if not M.table_eq(v, b[k], seen) then
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
```

## Functions

### Mock Factories

#### `helpers.mock_executor(responses)`

Creates a mock for `shell._executor`. Returns the mock function and a calls tracker:

```lua
local exec, calls = helpers.mock_executor({
    { true, 0 },   -- first call succeeds
    { false, 1 },  -- second call fails
})

shell._executor = exec

local ok1, code1 = shell.exec("ls", {"-la"})     -- ok1=true, code1=0
local ok2, code2 = shell.exec("false", {})        -- ok2=false, code2=1

assert(calls[1] == "ls '-la'")
assert(calls[2] == "false")
```

Calls beyond the response array return `{ false, 1 }` by default.

#### `helpers.mock_popen(outputs)`

Creates a mock for `shell._popen`. Same pattern as `mock_executor`:

```lua
local popen, calls = helpers.mock_popen({
    { true, "hello\n" },
})
shell._popen = popen
local ok, output = shell.capture("echo", {"hello"})
```

### Output Capture

#### `helpers.capture_output(fn)`

Temporarily replaces `io.write` to capture all output during `fn()`.
Restores the original `io.write` even if `fn` throws:

```lua
local output = helpers.capture_output(function()
    io.write("hello ")
    io.write("world")
end)
assert(output == "hello world")
```

### Assertion Helpers

#### `helpers.assert_errors(fn [, pattern])`

Asserts that `fn` throws an error. Optionally checks that the error message matches a Lua pattern:

```lua
helpers.assert_errors(function()
    error("something went wrong")
end, "went wrong")
```

#### `helpers.assert_no_errors(fn)`

Asserts that `fn` completes without throwing:

```lua
helpers.assert_no_errors(function()
    return 42
end)
```

### Temp Files

#### `helpers.with_temp_file(content, fn)`

Creates a temporary file with the given content, calls `fn(path)`, then cleans up — even if `fn` throws:

```lua
helpers.with_temp_file("key=value\n", function(path)
    local f = io.open(path, "r")
    local data = f:read("*a")
    f:close()
    assert(data == "key=value\n")
end)
-- temp file is deleted here
```

### Deep Equality

#### `helpers.table_eq(a, b)`

Deep table equality comparison with cycle detection:

```lua
helpers.table_eq({1, 2, 3}, {1, 2, 3})         --> true
helpers.table_eq({a = {b = 1}}, {a = {b = 1}}) --> true
helpers.table_eq({a = 1}, {a = 2})              --> false
```

Handles self-referencing and mutually-referencing cyclic structures without infinite recursion.

## Known Limitations

- **`capture_output` mock doesn't return file handle**: The real `io.write`
  returns the file handle for chaining (`io.write("a"):write("b")`).
  The mock returns nil, so chaining breaks.
- **Mock calls tracker is a shared mutable reference**: The caller can
  mutate the `calls` table, which could corrupt test assertions if not
  used carefully.
- **`with_temp_file` uses text mode**: The file is opened with `"w"`
  (text mode). On Windows, `\r\n` translation may alter binary content.
  On Unix this is not an issue.
- **`table_eq` and NaN**: Since `NaN ~= NaN` per IEEE 754, tables
  containing NaN values are never considered equal — even to themselves.
- **`table_eq` ignores metatables**: Comparison uses `pairs()` and raw
  value equality. Custom `__eq` metamethods are not invoked.
- **`assert_errors` with non-string errors**: Pattern matching uses
  `tostring(err)`, so table error objects produce `"table: 0x..."` which
  won't match meaningful patterns.
