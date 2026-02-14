# safe.shell

Safe shell execution with escaping and argument arrays. Never builds commands from raw strings. Includes a swappable executor for testing.

```lua
local shell = require("safe.shell")
```

## Source

```lua
--[[
  shell.lua — Safe shell execution with escaping and argument arrays.
  Never builds commands from raw strings. Swappable executor for testing.
]]

local M = {}

local type = type
local tostring = tostring
local string_format = string.format
local string_find = string.find
local string_gsub = string.gsub
local table_concat = table.concat
local error = error

--- Normalize os.execute return values across Lua 5.1 and 5.2+.
--- Lua 5.1: returns exit code (number)
--- Lua 5.2+: returns true/nil, "exit"/"signal", code
--- Exposed as M._normalize_exit for testing.
local function normalize_exit(...)
    local n = select("#", ...)
    if n >= 3 then
        local ok, _reason, code = ...
        return ok == true, code
    end
    -- Lua 5.1: single return value
    local code = ...
    if type(code) == "number" then
        return code == 0, code
    end
    return code == true, code and 0 or 1
end

--- Single-quote shell escaping.
--- Wraps argument in single quotes, escaping any embedded single quotes.
--- @param arg string
--- @return string escaped
function M.escape(arg)
    return "'" .. string_gsub(tostring(arg), "'", "'\\''") .. "'"
end

--- Escape an array of arguments and join with spaces.
--- @param args table array of string arguments
--- @return string escaped and joined
function M.escape_args(args)
    local parts = {}
    for i = 1, #args do
        parts[i] = M.escape(tostring(args[i]))
    end
    return table_concat(parts, " ")
end

--- Validate that a program name contains no shell metacharacters.
--- @param name string program name
--- @return boolean ok, string|nil err
function M.validate_program(name)
    if type(name) ~= "string" then
        return false, string_format("program name must be string, got %s", type(name))
    end
    if name == "" then
        return false, "program name must not be empty"
    end
    if string_find(name, "[;&|`$%(%){}%[%]<>!#~\"'%s]") then
        return false, string_format("program name contains shell metacharacters: %s", name)
    end
    return true, nil
end

--- Validate that all args are strings.
--- @param args table
--- @return boolean ok, string|nil err
function M.validate_args(args)
    if type(args) ~= "table" then
        return false, string_format("args must be table, got %s", type(args))
    end
    for i = 1, #args do
        if type(args[i]) ~= "string" then
            return false, string_format("arg[%d] must be string, got %s", i, type(args[i]))
        end
    end
    return true, nil
end

--- Build a shell command from program name and argument array.
--- @param program string
--- @param args table array of string arguments
--- @return string command
function M.build_command(program, args)
    local ok, err = M.validate_program(program)
    if not ok then
        error(err, 2)
    end
    if args and #args > 0 then
        return program .. " " .. M.escape_args(args)
    end
    return program
end

-- Swappable executor (default: os.execute wrapper)
M._executor = function(cmd)
    return normalize_exit(os.execute(cmd))
end

-- Swappable popen (default: io.popen wrapper)
M._popen = function(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then
        return false, nil
    end
    local output = handle:read("*a")
    handle:close()
    return true, output
end

--- Execute a command safely via program + args array.
--- @param program string
--- @param args table|nil array of string arguments
--- @return boolean ok, number|nil exit_code
function M.exec(program, args)
    local cmd = M.build_command(program, args or {})
    return M._executor(cmd)
end

--- Capture stdout from a command safely.
--- @param program string
--- @param args table|nil array of string arguments
--- @return boolean ok, string|nil output
function M.capture(program, args)
    local cmd = M.build_command(program, args or {})
    return M._popen(cmd)
end

M._normalize_exit = normalize_exit

return M
```

## Security Model

The shell module enforces safety at two levels:

1. **Program name validation**: `validate_program` rejects any program
   name containing shell metacharacters
   (``; & | ` $ ( ) { } [ ] < > ! # ~ " '`` and whitespace).
   This prevents command injection via the program name.

2. **Argument escaping**: All arguments are wrapped in single quotes
   with embedded single quotes properly escaped (`'` becomes `'\''`).
   This is the standard POSIX shell escaping technique.

The combination means that
`shell.exec("grep", {"-r", user_input, "/path"})` is safe even when
`user_input` contains `; rm -rf /` — the dangerous content is safely
single-quoted:

```lua
shell.build_command("echo", { "; rm -rf /" })
--> echo '; rm -rf /'
```

## Functions

### `shell.escape(arg)`

Single-quote shell escaping:

```lua
shell.escape("hello world")  --> 'hello world'
shell.escape("it's")          --> 'it'\''s'
shell.escape("line1\nline2")  --> 'line1\nline2'
```

### `shell.escape_args(args)`

Escape and join an array of arguments:

```lua
shell.escape_args({"a", "b c", "d'e"})
--> 'a' 'b c' 'd'\''e'
```

### `shell.validate_program(name)` / `shell.validate_args(args)`

Non-throwing validation:

```lua
local ok, err = shell.validate_program("ls")        -- ok = true
local ok, err = shell.validate_program("ls -la")     -- ok = false (space)
local ok, err = shell.validate_program("ls\nrm /")   -- ok = false (newline)
```

### `shell.build_command(program, args)`

Build a command string. Throws on invalid program name:

```lua
shell.build_command("grep", {"-r", "pattern", "."})
--> grep '-r' 'pattern' '.'
```

### `shell.exec(program, args)` / `shell.capture(program, args)`

Execute a command or capture its stdout:

```lua
local ok, code = shell.exec("ls", {"-la", "/tmp"})
local ok, output = shell.capture("date", {"+%Y-%m-%d"})
```

### Swappable Executors

For testing, replace `_executor` and `_popen` with mocks (see [test_helpers](test_helpers.md)):

```lua
local helpers = require("safe.test_helpers")
local exec, calls = helpers.mock_executor({{ true, 0 }})
shell._executor = exec
shell.exec("ls", {"-la"})
assert(calls[1] == "ls '-la'")
```

## Known Limitations

- **Null byte passthrough**: `shell.escape("a\0b")` passes the null byte through inside single quotes. Behavior is shell-dependent and potentially dangerous.
- **`validate_args` ignores hash keys**: Only numeric indices `1..#args` are checked. Non-sequential keys (e.g., `{[1]="a", extra="b"}`) are silently ignored.
- **Lua 5.1/5.2+ portability**: `normalize_exit` handles both return conventions, but edge cases with `nil` returns are mapped to `false, 1`.
