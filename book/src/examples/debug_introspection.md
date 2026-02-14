# Debug Introspection

Lua's `debug` library provides powerful runtime introspection
capabilities, but using it safely requires careful patterns.
This example demonstrates six debug library idioms drawn from
real-world projects: AwesomeWM's `gears.debug` (deprecation
warnings with call-site deduplication), APISIX's `inspect/dbg.lua`
(function metadata and safe stringification), and common
defensive patterns for stack inspection and traceback formatting.

## Key Patterns

- **`debug.getinfo(level, "Sl")`**: Extract source file and
  line number at a given stack level for caller identification
- **`debug.traceback` wrapper**: Clean traceback formatting
  with optional prefix stripping
- **Once-per-call-site warnings**: Use `debug.getinfo` to
  build a `source:line` key; a closure-captured "seen" set
  suppresses duplicate warnings (AwesomeWM pattern)
- **Function reflection**: `debug.getinfo(fn, "Slu")` reveals
  source, line range, upvalue count, and Lua-vs-C classification
- **Stack depth measurement**: Iterate `debug.getinfo(i, "")`
  upward until `nil` to count frames; useful for recursion guards
- **Safe tostring**: Wrap `tostring` in `pcall` to survive
  broken `__tostring` metamethods; fall back to raw type and
  address on failure

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.assert_type` on all function arguments (level, fn, old_name, etc.) |
| CB-601 | `guard.contract` for level >= 1 and positive ranges |
| CB-602 | `validate.check_type` for non-throwing msg validation in format_traceback |
| CB-605 | `pcall` around `tostring` in safe_tostring to handle broken metamethods |
| CB-607 | Closure-captured `seen` set in deprecation_warning for stateful tracking |

## Source

```lua
{{#include ../../../examples/debug_introspection.lua}}
```

## Sample Output

```text
Debug Library Introspection Patterns
============================================================
Six patterns from AwesomeWM, APISIX, and defensive Lua.

============================================================
  Pattern 1: Caller Info (debug.getinfo)
============================================================

  source: examples/debug_introspection.lua  line: 157
  level 1: examples/debug_introspection.lua:48
  level 2: examples/debug_introspection.lua:162
  level 3: examples/debug_introspection.lua:316
  level 4: examples/debug_introspection.lua:330

  Type guard: ok=false err=...expected level to be number, got string

============================================================
  Pattern 2: Clean Traceback Formatter
============================================================

--- Formatted traceback from nested calls ---
  error occurred here
    examples/debug_introspection.lua:68: in function <...>
    (tail call): ?
    (tail call): ?
    (tail call): ?
    examples/debug_introspection.lua:185: in function 'demo_traceback'
    ...


============================================================
  Pattern 3: Deprecation Warning (AwesomeWM gears.debug)
============================================================

--- Three calls from same call site (warns once) ---
[...] [WARN] [debug-intro] old_api is deprecated, use new_api instead (at @...:199)
  call 1: result=old result
  call 2: result=old result
  call 3: result=old result

--- Call from different call site (warns again) ---
[...] [WARN] [debug-intro] old_api is deprecated, use new_api instead (at @...:204)
  result=old result

  Type guard: ok=false err=...expected old_name to be string, got number

============================================================
  Pattern 4: Function Metadata (debug.getinfo)
============================================================

  Function                  What   Ups    Source
  -------------------------------------------------------
  demo_function_info        Lua    12     examples/debug_introspection.lua
  guard.assert_type         Lua    4      lib/safe/guard.lua
  log.info                  Lua    2      lib/safe/log.lua
  string.format             C      0      [C]
  pairs                     C      1      [C]
  type                      C      0      [C]

  Type guard: ok=false err=...expected fn to be function, got string

============================================================
  Pattern 5: Stack Depth Measurement
============================================================

  Current depth: 5

  recursion level 1 -> stack depth 6
  recursion level 2 -> stack depth 7
  recursion level 3 -> stack depth 8
  recursion level 4 -> stack depth 9
  recursion level 5 -> stack depth 10
  Increment per level: 1

============================================================
  Pattern 6: Safe Tostring (APISIX inspect/dbg.lua)
============================================================

  number         -> 42
  string         -> hello
  boolean        -> true
  nil            -> nil
  plain table    -> table: 0x...

  good __tostring   -> MyObject{ok}
  broken __tostring -> <table 0x... (__tostring error)>
  non-string return -> 12345
  function value    -> function: 0x...

============================================================
Debug Introspection Summary
============================================================

#     Pattern                        Source
------------------------------------------------------------
1     Caller info (getinfo)          logging / error reporters
2     Clean traceback formatter      debug.traceback wrapper
3     Deprecation warning (once)     AwesomeWM gears.debug
4     Function metadata              APISIX inspect/dbg.lua
5     Stack depth measurement        recursion limiting
6     Safe tostring                  APISIX inspect/dbg.lua
------------------------------------------------------------

Done.
```

## Pattern Reference

| Pattern | debug API Used | Real-World Project | Use Case |
|---------|---------------|--------------------|----------|
| Caller info | `debug.getinfo(level, "Sl")` | Logging frameworks | Identify call site in log messages |
| Clean traceback | `debug.traceback(msg, level)` | Error handlers | Readable stack traces without noise |
| Deprecation warning | `debug.getinfo` + seen set | AwesomeWM `gears.debug` | Warn once per call site on API migration |
| Function metadata | `debug.getinfo(fn, "Slu")` | APISIX `inspect/dbg.lua` | Runtime function reflection and documentation |
| Stack depth | `debug.getinfo(i, "")` loop | Recursion guards | Detect and limit deep call chains |
| Safe tostring | `pcall(tostring, v)` + fallback | APISIX `inspect/dbg.lua` | Stringify values with broken metamethods |
