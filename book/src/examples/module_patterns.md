# Module Patterns

Lua has no built-in module system beyond `require` and
`return`. Every project must choose how to structure its
modules, and over time seven dominant idioms have emerged
across the ecosystem. This example demonstrates each one
with safe-lua defensive checks throughout.

Understanding these patterns matters because:

- Different projects use different idioms; recognizing
  them prevents misuse when integrating third-party code.
- Each pattern has distinct trade-offs in encapsulation,
  extensibility, and API ergonomics.
- Defensive initialization (guard/validate) catches
  misconfiguration early rather than at runtime.

## Key Patterns

- **Return-table**: `local M = {} ... return M`. The
  canonical Lua module. No metatable overhead.
- **Callable module**: `__call` metamethod wraps `new()`,
  enabling `require("cache")(size)` one-liners.
- **Stdlib extension**: `setmetatable(M, {__index = table})`
  inherits all `table.*` functions, then adds custom ones.
- **Private constructor**: Module exposes only `new()`;
  internal helpers remain local, enforcing information hiding.
- **Hierarchical namespace**: Parent module with sub-tables
  (`M.utils`, `M.types`) for organized API surfaces.
- **Lazy-init**: `init(config)` must be called before use;
  `guard.contract` enforces the initialization order.
- **Versioning**: `_VERSION`, `_DESCRIPTION`, `_LICENSE`
  metadata fields with semantic version comparison.

## CB Checks Demonstrated

| Check  | Where                                         |
|--------|-----------------------------------------------|
| CB-600 | `guard.contract` on cache capacity, init flag |
| CB-601 | `guard.safe_get` style nil-safe patterns      |
| CB-602 | `guard.assert_type` on all public parameters  |
| CB-605 | `guard.assert_not_nil` on cache values        |
| CB-607 | `validate.Checker` colon-syntax accumulation  |

## Source

```lua
{{#include ../../../examples/module_patterns.lua}}
```

## Sample Output

```text
Module Definition Idioms in Lua 5.1
============================================================
Seven patterns from APISIX, AwesomeWM, Kong, xmake,
luasocket, and lpeg — with safe-lua defensive checks.

------------------------------------------------------------
Pattern: 1. Return-Table Module (standard)
------------------------------------------------------------
  hello("Lua")   = Hello, Lua!
  goodbye("Lua") = Goodbye, Lua!

------------------------------------------------------------
Pattern: 2. Module with __call (AwesomeWM gears.cache)
------------------------------------------------------------
  Via .new():  get("host") = localhost
  Via __call:  get("port") = 8080

------------------------------------------------------------
Pattern: 3. Module Extending stdlib (APISIX core.table)
------------------------------------------------------------
  tbl.sort (inherited): 1, 1, 3, 4, 5
  tbl.is_empty({}):     true
  tbl.keys(data):       host, port
  tbl.shallow_copy:     host=localhost

------------------------------------------------------------
Pattern: 4. Private Constructor (Kong PDK)
------------------------------------------------------------
  Pending: 3
  Flushed: [INFO] auth-service: started
  Flushed: [WARN] auth-service: token expiring
  Flushed: [ERR] auth-service: refresh failed
  After flush: 0 pending

------------------------------------------------------------
Pattern: 5. Hierarchical Module (namespace pattern)
------------------------------------------------------------
  sdk._NAME:              app-sdk
  utils.slugify:          hello-world
  utils.truncate(6 -> 4): abcd...
  types.is_string("y"):   true
  types.is_positive_int:  true
  check_record:           ok=false err=expected age to be non-nil

------------------------------------------------------------
Pattern: 6. Lazy-Init Module (deferred initialization)
------------------------------------------------------------
  Before init: initialized=false
  query before init: ok=false
  Error: database not initialized: call init() first
  After init:  initialized=true
  connection_info = db.local:5432/app_prod
  query("SELECT 1") = result from db.local:5432/app_prod: [SELECT 1]

------------------------------------------------------------
Pattern: 7. Module Versioning (metadata pattern)
------------------------------------------------------------
  _VERSION=2.3.1  _LICENSE=MIT
  version_info: 2.3.1 (Versioned utility module) [MIT]
  check("2.3.0"): ok=true err=nil
  check("2.3.1"): ok=true err=nil
  check("2.4.0"): ok=false err=minor too old: need 2.4+, have 2.3.1
  check("3.0.0"): ok=false err=major mismatch: need 3, have 2

============================================================
Done.
```

## Pattern Reference

| Pattern              | Source Projects       | Key Advantage          |
|----------------------|-----------------------|------------------------|
| Return-table         | safe-lua, lpeg        | Minimal, no metatable  |
| Callable module      | AwesomeWM, lazy.nvim  | Ergonomic one-liner    |
| Stdlib extension     | APISIX core.table     | Inherit + extend       |
| Private constructor  | Kong PDK              | Information hiding     |
| Hierarchical         | Kong, xmake           | Organized namespaces   |
| Lazy-init            | APISIX, Kong plugins  | Controlled lifecycle   |
| Versioning           | luasocket, lpeg       | Compatibility checks   |
