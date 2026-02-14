# OOP Patterns

Lua has no built-in class system, yet every major Lua
project implements object-oriented patterns. This example
demonstrates the five dominant OOP idioms found across
Kong, KOReader, lazy.nvim, AwesomeWM, lite-xl, and xmake
-- with safe-lua defensive validation in every constructor.

Understanding these patterns matters because:

- Lua codebases mix idioms freely; recognizing them
  prevents misuse and subtle bugs.
- Each pattern has distinct trade-offs in memory, lookup
  speed, and composability.
- Defensive constructors (guard/validate) catch misuse
  at creation time rather than at call time.

## Key Patterns

- **Separate metatable**: Module table holds methods,
  private `mt` table wires `__index`. Clean namespace.
- **Prototypal inheritance**: `:extend()` creates a child
  whose metatable is the parent. No class table needed.
- **__call constructor**: `setmetatable(M, {__call = ...})`
  lets you write `Color(255, 0, 0)` instead of
  `Color.new(255, 0, 0)`.
- **Self-as-metatable**: The instance IS its own
  metatable. Compact, one fewer table allocation.
- **Copy-based inheritance**: Functions copied from base
  to child. No chain lookups at runtime.

## CB Checks Demonstrated

| Check  | Where                                   |
|--------|-----------------------------------------|
| CB-600 | `guard.contract` on port/priority range |
| CB-601 | `guard.safe_get` in Emitter.emit        |
| CB-607 | `validate.Checker` colon-syntax         |

## Source

```lua
{{#include ../../../examples/oop_patterns.lua}}
```

## Sample Output

```text
OOP Patterns in Lua 5.1
============================================================
Five idioms from Kong, KOReader, lazy.nvim, AwesomeWM,
lite-xl, and xmake — with safe-lua defensive validation.

------------------------------------------------------------
Pattern: 1. Separate Metatable (Kong/APISIX)
------------------------------------------------------------
  Created:  auth-api (port 8443) [UP]
  Healthy?  true
  After failure: auth-api (port 8443) [DOWN]

------------------------------------------------------------
Pattern: 2. Prototypal Inheritance (KOReader/lite-xl)
------------------------------------------------------------
  Widget: panel (800x600)  area=480000
  Button: Button[OK] (120x40)  area=4800

------------------------------------------------------------
Pattern: 3. __call Constructor (lazy.nvim/AwesomeWM)
------------------------------------------------------------
  Via .new():  rgb(255, 0, 0) = #FF0000
  Via __call:  rgb(0, 0, 255) = #0000FF

------------------------------------------------------------
Pattern: 4. Self-as-Metatable (xmake)
------------------------------------------------------------
  Task 1: [P1] build (DONE)
  Task 2: [P2] test (OPEN)
  t1 == getmetatable(t1)? true

------------------------------------------------------------
Pattern: 5. Copy-based Inheritance (AwesomeWM)
------------------------------------------------------------
  [listener] boot complete
  [listener] ready for traffic
  Total captured messages: 2

============================================================
Done.
```

## Pattern Reference

| Pattern               | Projects            | Pros             |
|-----------------------|---------------------|------------------|
| Separate metatable    | Kong, APISIX        | Clean namespace  |
| Prototypal inherit.   | KOReader, lite-xl   | Zero boilerplate |
| __call constructor    | lazy.nvim, AwesomeWM| Ergonomic API    |
| Self-as-metatable     | xmake               | Compact, fast    |
| Copy-based inherit.   | AwesomeWM           | No chain lookups |
