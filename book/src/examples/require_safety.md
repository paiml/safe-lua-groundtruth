# Require Safety

Lua's `require` function loads modules by searching
`package.path` for matching files, executing them once,
and caching the result in `package.loaded`. This
design is simple but has sharp edges: circular
dependencies return partial tables, missing modules
crash at runtime, and debugging path resolution
errors requires understanding the search algorithm.

This example demonstrates six defensive patterns
that production Lua projects use to handle module
loading safely.

## Key Patterns

- **Require cycle detection**: Understand why
  circular `require` returns an incomplete table
  and how capturing functions (not tables) during
  a cycle silently yields nil
- **Lazy require**: Defer `require()` inside
  functions to break cycles and delay loading
  (Kong, lazy.nvim, APISIX)
- **Safe require with pcall**: Load optional
  modules without crashing; provide fallback
  behavior when dependencies are missing
- **Load order verification**: Validate all
  critical modules before proceeding; fail fast
  with clear error messages
- **package.loaded inspection**: Check the module
  cache to avoid redundant loads and understand
  runtime state
- **Path debugging**: Resolve which file paths Lua
  searches and find where a module actually lives

## CB Checks Demonstrated

| Check  | Where                                      |
|--------|--------------------------------------------|
| CB-600 | `guard.contract` validates load results    |
| CB-601 | `guard.assert_type` on function parameters |
| CB-607 | `validate.Checker` for load count check    |

## Source

```lua
{{#include ../../../examples/require_safety.lua}}
```

## Sample Output

```text
Require Safety Patterns (from top Lua projects)
============================================================

1. Require Cycle Problem
------------------------------------------------------------
When module A requires B which requires A, the second
require returns A's PARTIAL table (whatever was set so far).

  A finished loading:       true
  B sees A.greet (after):   true
  B captured A's table reference early, so it sees
  the completed table (Lua tables are references).

  Captured function directly: nil
  A2.greet after completion:  true
  Capturing a function (not the table) during a cycle
  gives nil -- this is the real require-cycle bug.

2. Lazy Require Pattern (Kong, lazy.nvim)
------------------------------------------------------------
Defer require() inside functions to break cycles and
avoid loading modules until they are actually needed.

  Calling get_validate() for the first time...
  validate.check_type('hello', 'string'): ok=true
  Same module instance: true
  Lazy guard loaded: true

  Kong uses this pattern in its plugin loading to avoid
  circular dependencies between handler and schema modules.

3. Safe Require with pcall (Universal)
------------------------------------------------------------
Use pcall(require, name) for optional dependencies.
Gracefully degrade when a module is not available.

[...] [WARN] [require-safety] optional module not available: ...
  pcall(require, 'nonexistent_optional_module'):
    ok=false  err=module 'nonexistent_optional_module' not found: ...
  pcall(require, 'safe.log'):
    ok=true  module=table

  Graceful degradation example:
    cjson not available, using basic fallback
    json_encode result: {<table: table: 0x...>}

4. Module Load Order Verification
------------------------------------------------------------
Verify all critical modules loaded before proceeding.
Fail fast with clear errors on missing dependencies.

  [OK]   safe.guard
  [OK]   safe.validate
  [OK]   safe.log

  Optional modules:
  [OK]   safe.perf (available)
  [SKIP] safe.nonexistent (not found: ...)

  Required: 3/3 loaded

5. package.loaded Inspection
------------------------------------------------------------
Inspect what modules are cached in package.loaded.
Detect whether a module is already loaded without
triggering a new require.

  Module cache status:
    safe.guard           loaded (table)
    safe.validate        loaded (table)
    safe.log             loaded (table)
    cjson                not loaded
    lpeg                 not loaded

  Total cached modules: 13
  safe.* modules:       4

  Conditional require pattern:
    safe.guard already loaded, reusing cached version
    guard.freeze available: true

6. Require Path Debugging
------------------------------------------------------------
Debug module loading failures by inspecting the search
paths that Lua tries when require() is called.

  Resolving 'safe.guard':
    Found at: lib/safe/guard.lua
    Paths searched: 8

  Resolving 'nonexistent.module':
    Found: nil
    Paths tried:
      lib/nonexistent/module.lua
      ./nonexistent/module.lua
      /usr/local/share/lua/5.1/nonexistent/module.lua
      /usr/local/share/lua/5.1/nonexistent/module/init.lua
      ... and 4 more

============================================================
Pattern Summary
============================================================

  Pattern                        Real-World Usage
  ------------------------------ ----------------------------
  Require cycle awareness        All large Lua projects
  Lazy require                   Kong, lazy.nvim, APISIX
  pcall(require, name)           Universal (all projects)
  Load order verification        xmake, KOReader, Prosody
  package.loaded inspection      Kong, AwesomeWM, Neovim
  Path debugging                 Debugging any project

============================================================
Results Matrix
============================================================
  Pattern                                       Status
------------------------------------------------------------
  1. Require cycle problem                      [PASS]
  2. Lazy require (Kong, lazy.nvim)             [PASS]
  3. Safe require with pcall                    [PASS]
  4. Module load order verification             [PASS]
  5. package.loaded inspection                  [PASS]
  6. Require path debugging                     [PASS]
------------------------------------------------------------
  6/6 passed
```

## Pattern Reference

| Pattern                 | Projects                  | Use Case                  |
|-------------------------|---------------------------|---------------------------|
| Require cycle awareness | All large Lua projects    | Prevent partial-table bugs|
| Lazy require            | Kong, lazy.nvim, APISIX   | Break circular deps       |
| pcall(require, name)    | Universal                 | Optional dependencies     |
| Load order verification | xmake, KOReader, Prosody  | Fail-fast startup         |
| package.loaded inspect  | Kong, AwesomeWM, Neovim   | Avoid redundant loads     |
| Path debugging          | Any project               | Diagnose load failures    |
