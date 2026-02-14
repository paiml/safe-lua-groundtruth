# Error Handling Patterns

Demonstrates the eight most common error handling patterns
found across top Lua projects including Kong, APISIX, xmake,
AwesomeWM, LOVE, and lazy.nvim. Each pattern is a working
function with actual output and a pass/fail results matrix.

## Patterns Covered

| # | Pattern | Projects |
|---|---------|----------|
| 1 | `return nil, err` | Kong, APISIX, xmake |
| 2 | `pcall` wrapping | Universal |
| 3 | `xpcall` with traceback | AwesomeWM, LOVE, lazy.nvim |
| 4 | `error(msg, level)` | Kong, OpenResty |
| 5 | `assert()` vs `error()` | All (context-dependent) |
| 6 | Error concatenation safety | All |
| 7 | Silent failure anti-pattern | Common defect |
| 8 | Three-value pcall unpacking | Kong |

## Key Takeaways

- **`return nil, err`** is the dominant Lua error pattern.
  Always propagate with context:
  `return nil, "caller: " .. tostring(err)`.
- **`pcall`** converts thrown errors to return values.
  Check the boolean first, then inspect the second value.
- **`xpcall`** adds a custom error handler that can capture
  `debug.traceback` before the stack unwinds.
- **`error(msg, 2)`** points the error at the caller, not at
  the function that detected the problem. Preferred in
  library APIs over `assert()`.
- **`tostring(err)`** before concatenation prevents crashes
  when `err` is `nil`. This is the single most common Lua
  error-handling bug.
- **Always check `io.open` return values.** Silent failures
  from unchecked nil file handles are a top defect source.
- **Three-value pcall** arises when `pcall` wraps a function
  that itself returns `ok, err`. Normalize to two values.

## Source

```lua
{{#include ../../../examples/error_handling.lua}}
```

## Sample Output

```text
Error Handling Patterns (from top Lua projects)
============================================================

1. return nil, err (Kong, APISIX, xmake)
------------------------------------------------------------
  parse_port('8080'): port=8080 err=nil
  parse_port('99999'): port=nil err=parse_port: port must be between 1 and 65535, got 99999
  parse_port(42):      port=nil err=parse_port: expected input to be string, got number
  connect('localhost','abc'): connect: parse_port: not a number: abc

2. pcall wrapping (universal)
------------------------------------------------------------
  pcall(decode, 'hello'): ok=true result=decoded:hello
  pcall(decode, ''):      ok=false err=...error_handling.lua:117: empty input
  pcall(decode, 42):      ok=false err=expected input to be string, got number

3. xpcall with error handler (AwesomeWM, LOVE)
------------------------------------------------------------
  xpcall ok:     false
  error:         ...error_handling.lua:142: something broke in deep_call
  traceback (first 3 lines):
    ...error_handling.lua:142: something broke in deep_call
    stack traceback:
    ...error_handling.lua:142: in function 'deep_call'

4. error(msg, level) with stack levels (Kong)
------------------------------------------------------------
  level 1 error: ...error_handling.lua:162: bad_api: expected string, got number
  level 2 error: ...error_handling.lua:171: bad_api: expected string, got number
  guard.assert_type: expected config to be table, got nil

5. assert() vs error() — library vs test
------------------------------------------------------------
  In tests: assert(value == expected) is idiomatic
  lib error(msg, 2): ...error_handling.lua:189: set_timeout: seconds must be positive number
  guard.contract:    contract violated
  Recommendation: error(msg, 2) in libraries,
                  assert() in tests

6. Error concatenation safety
------------------------------------------------------------
  raw error type: string
  concat nil crashes: true (attempt to concatenate local 'nil_err' (a nil value))
  safe tostring():    open failed: /nonexistent/path: No such file or directory
  string.format:      open failed: /nonexistent/path: No such file or directory

7. Silent failure anti-pattern
------------------------------------------------------------
  Defect (unchecked io.open):
    local f = io.open(path)
    f:read('*a')  -- crashes if path missing!

  unchecked crash: ok=false err=attempt to index local 'f' (a nil value)

  Correct pattern:
  safe_read: content=nil err=cannot open: /nonexistent/file.txt: No such file or directory
  safe_read(''): content=nil err=path must not be empty

8. Three-value pcall unpacking (Kong)
------------------------------------------------------------
  Standard two-layer unwrap:
    query ok: rows=3

  Kong-style normalization:
    safe_query('SELECT 1'): ok=true
    safe_query('DROP...'): err=forbidden: DROP not allowed
    safe_query(''):        err=sql must not be empty

============================================================
Results Matrix
============================================================
  Pattern                                       Status
------------------------------------------------------------
  1. return nil, err                            [PASS]
  2. pcall wrapping                             [PASS]
  3. xpcall with traceback                      [PASS]
  4. error(msg, level)                          [PASS]
  5. assert() vs error()                        [PASS]
  6. Concatenation safety                       [PASS]
  7. Silent failure detection                   [PASS]
  8. Three-value pcall unpacking                [PASS]
------------------------------------------------------------
  8/8 passed
```
