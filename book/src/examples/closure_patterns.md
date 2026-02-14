# Closure Patterns

Closures are functions that capture variables from their
enclosing scope. In Lua, these captured variables are called
upvalues. Every time a function is created inside another
function, it closes over the local variables it references,
creating a private, persistent binding that survives the
outer function's return.

This example demonstrates six closure and upvalue patterns
drawn from real-world Lua projects including AwesomeWM's
`gears.cache` (closure-based cache factory), Kong balancer
factories, and APISIX plugin factories.

## Key Patterns

- **Factory function**: `make_validator(rules)` captures a
  rules table as an upvalue and returns a validation function
  that checks records against those rules
- **Partial application**: `partial(fn, ...)` captures a
  function and its first arguments, returning a new function
  that appends remaining arguments at call time
- **Memoization**: `memoize(fn)` captures an internal cache
  table as an upvalue, returning cached results on repeated
  calls with the same argument
- **Shared state**: `make_counter(initial)` returns multiple
  functions (increment, decrement, get, reset) that all
  close over the same `count` variable, achieving
  encapsulation without metatables
- **Closure vs coroutine iterators**: Side-by-side comparison
  of `range_closure` (upvalue-based state) and
  `range_coroutine` (`coroutine.wrap`-based state)
- **Pipeline builder**: Accumulates transformation functions
  in an upvalue array; `:run(input)` feeds input through
  all steps sequentially

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.assert_type` on all function arguments |
| CB-601 | `guard.contract` for step-not-zero, pipeline-not-empty |
| CB-607 | `validate.Checker` for counter initial value validation |

## Source

```lua
{{#include ../../../examples/closure_patterns.lua}}
```

## Sample Output

```text
Closure Patterns
============================================================
Six patterns demonstrating closures and upvalues in Lua.
Source: AwesomeWM gears.cache, Kong balancers, APISIX plugins.

============================================================
  Pattern 1: Factory Function (AwesomeWM, Kong)
============================================================

--- Valid record ---
  valid: ok=true err=nil
--- Invalid record (wrong types) ---
  invalid: ok=false err=expected name to be string, got number; ...
--- Missing fields ---
  partial: ok=false err=expected age to be number, got nil; ...


============================================================
  Pattern 2: Partial Application
============================================================

--- Partial add ---
  add10(5)  = 15
  add10(20) = 30
--- Partial format ---
  log_line("INFO", "server", "started") = [INFO] server: started
  log_line("ERR", "db", "timeout")     = [ERR] db: timeout


============================================================
  Pattern 3: Memoize via Closure (gears.cache)
============================================================

--- First calls (cache misses) ---
  square(4)  = 16
  square(7)  = 49
  square(12) = 144
--- Repeated calls (cache hits) ---
  square(4)  = 16
  square(7)  = 49
  square(4)  = 16

  Cache stats: hits=3 misses=3
  Actual fn calls: 3 (saved 3)


============================================================
  Pattern 4: Shared State (Counter Module)
============================================================

--- Increment ---
  increment()  -> 1
  increment()  -> 2
  increment(5) -> 7
--- Decrement ---
  decrement()  -> 6
  decrement(3) -> 3
--- Get and reset ---
  get()   -> 3
  reset() -> 0
  get()   -> 0


============================================================
  Pattern 5: Closure vs Coroutine Iterators
============================================================

--- Closure-based range(1, 5) ---
  1, 2, 3, 4, 5
--- Coroutine-based range(1, 5) ---
  1, 2, 3, 4, 5
--- Countdown range(10, 1, -3) ---
  closure:   10, 7, 4, 1
  coroutine: 10, 7, 4, 1
  identical: true


============================================================
  Pattern 6: Pipeline Builder (APISIX)
============================================================

--- String transformation pipeline ---
  input:  "  Hello, World!  Welcome to Lua.  "
  output: "_hello_world_welcome_to_lua_"
  steps:  3
--- Numeric pipeline ---
  pipeline(5): (5*2 + 10)^2 = 400
  pipeline(3): (3*2 + 10)^2 = 256

============================================================
All closure patterns demonstrated successfully.
```

## Pattern Reference

| Pattern | Upvalue | Returned | Use Case |
|---------|---------|----------|----------|
| Factory | config table | specialized function | Validator, parser, formatter factories |
| Partial | fn + first args | curried function | Callback wiring, event handlers |
| Memoize | cache table + counters | caching wrapper | Expensive computation, gears.cache |
| Shared state | mutable variable | multi-function API | Encapsulated modules without metatables |
| Closure iterator | mutable counter | stateless-style iterator | `for val in iter()` loops |
| Pipeline | step array | chainable builder | Request/response middleware chains |
