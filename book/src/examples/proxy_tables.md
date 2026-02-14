# Proxy Tables

Lua's `__index` and `__newindex` metamethods let you
intercept every read and write on a table. By placing an
empty proxy table in front of the real data, you gain full
control over access without modifying the original table.

This example demonstrates five proxy patterns drawn from
real Lua projects: AwesomeWM's immutable matrices,
lazy.nvim's virtual semver fields, and Hammerspoon's
watchable change-detection system.

## Key Patterns

- **Read-only proxy**: `__newindex` errors on any write,
  `__index` delegates to the original table. Provides a
  `proxy_pairs()` helper since Lua 5.1 lacks `__pairs`.
- **Logging proxy**: `__index` and `__newindex` both log
  the key (and value for writes) before delegating.
  Useful for discovering actual access patterns.
- **Validation proxy**: `__newindex` checks that the field
  exists in a schema and that the value type matches
  before allowing the write through.
- **Computed properties**: `__index` checks a table of
  virtual field functions first, falls back to real data.
  `__newindex` blocks writes to computed fields.
- **Change detector**: `__newindex` compares old and new
  values via `rawget`/`rawset`, only firing a callback
  when the value actually changes.

## CB Checks Demonstrated

| Check  | Where                                          |
|--------|------------------------------------------------|
| CB-601 | `guard.assert_type` on all proxy constructors  |
| CB-602 | `guard.assert_type` in validation proxy writes |
| CB-605 | `validate.check_range` in change detection     |
| CB-607 | `validate.Checker` not used (dot-syntax only)  |

## Source

```lua
{{#include ../../../examples/proxy_tables.lua}}
```

## Sample Output

```text
Proxy Table Patterns (__newindex / __index)
============================================================
Five patterns from Hammerspoon, lazy.nvim, and AwesomeWM.

------------------------------------------------------------
Pattern: 1. Read-only Proxy (AwesomeWM gears.matrix)
------------------------------------------------------------
  host:    api.example.com
  port:    443
  retries: 3
  Iterating via proxy_pairs:
    host = api.example.com
    port = 443
    retries = 3
  Write blocked:  true
    Error: ...attempt to modify read-only table key: port
  Original port:  443

------------------------------------------------------------
Pattern: 2. Logging Proxy (access tracer)
------------------------------------------------------------
  Reading 'mode':
    got: fast
  Writing 'count' = 5:
    backing store: count=5
  Reading unknown key 'missing':
    got: nil

------------------------------------------------------------
Pattern: 3. Validation Proxy (schema-enforced writes)
------------------------------------------------------------
  name:   Alice
  age:    30
  active: true
  Updated age: 31
  Bad type blocked: true
    Error: ...expected age to be number, got string
  Unknown field blocked: true
    Error: ...unknown field: email (not in schema)

------------------------------------------------------------
Pattern: 4. Computed Properties (lazy.nvim semver)
------------------------------------------------------------
  first_name: Grace
  last_name:  Hopper
  full_name:  Grace Hopper (computed)
  age_approx: 120 (computed)
  Updated first_name: Rear Admiral Grace
  full_name now:      Rear Admiral Grace Hopper
  Computed write blocked: true
    Error: ...cannot write to computed field: full_name

------------------------------------------------------------
Pattern: 5. Change Detector (Hammerspoon watchable)
------------------------------------------------------------
  Setting volume = 75 (change):
    CHANGED volume: 50 -> 75
  Setting volume = 75 (no change, same value):
  Setting muted = true (change):
    CHANGED muted: false -> true
  Setting muted = true (no change, same value):
  Setting volume = 0 (change):
    CHANGED volume: 75 -> 0
  Total change events fired: 3 (expected 3)
  Validated: exactly 3 changes detected.

============================================================
Proxy Pattern Summary
============================================================

  Pattern                 Source          Purpose
  --------------------------------------------------------
  Read-only proxy         AwesomeWM       Immutable config
  Logging proxy           Debug tool      Access tracing
  Validation proxy        Schema guard    Type-safe writes
  Computed properties     lazy.nvim       Virtual fields
  Change detector         Hammerspoon     Watch for changes
  --------------------------------------------------------

  All patterns use empty proxy + metatable delegation.
  Lua 5.1: __pairs not supported; provide helper functions.

Done.
```

## Pattern Reference

| Pattern             | Source Project | Metamethods              |
|---------------------|---------------|--------------------------|
| Read-only proxy     | AwesomeWM     | `__index`, `__newindex`  |
| Logging proxy       | Debug tool    | `__index`, `__newindex`  |
| Validation proxy    | Schema guard  | `__index`, `__newindex`  |
| Computed properties | lazy.nvim     | `__index`, `__newindex`  |
| Change detector     | Hammerspoon   | `__index`, `__newindex`  |
