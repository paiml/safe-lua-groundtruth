# Weak Tables

Lua's weak tables allow the garbage collector to reclaim
entries that have no other references. This is controlled
by the `__mode` field on a table's metatable: `"v"` for
weak values, `"k"` for weak keys, and `"kv"` for both.

Weak tables are essential for caches, identity tracking,
and metadata association patterns found across major Lua
projects including Kong, AwesomeWM, KOReader, lazy.nvim,
and APISIX.

## Key Patterns

- **Weak-value cache**: `__mode = "v"` lets GC reclaim
  cached values when no external references remain
- **Weak-key tracking**: `__mode = "k"` attaches metadata
  to objects without preventing their collection
- **Ephemeral associations**: `__mode = "kv"` for fully
  transient key-value mappings
- **String key anti-pattern**: strings are interned and
  never collected, defeating weak-key semantics
- **Memoization**: weak-value cache for computed results
  that can be reclaimed under memory pressure
- **Object metadata**: debug/profiling info attached via
  weak-key table, auto-cleaned when objects are collected

## Weak Mode Reference

| Mode | Weak Ref | Use Case |
|------|----------|----------|
| `__mode="v"` | Values only | Caches, memoization |
| `__mode="k"` | Keys only | Identity tracking |
| `__mode="kv"` | Keys + values | Ephemeral mappings |

**Caveat:** String, number, and boolean keys are interned
in Lua and are never garbage-collected. Always use table
(reference type) keys in weak-key tables.

## Source

```lua
{{#include ../../../examples/weak_tables.lua}}
```

## Sample Output

```text
Weak Table Patterns from Top Lua Projects
============================================================

1. Weak Values Cache (__mode = "v")
------------------------------------------------------------
Pattern: cache that allows GC to reclaim unused values.
Used by Kong for per-request data, AwesomeWM for widget caches.

  Before GC: 2 entries in cache
  After GC:  1 entries in cache (dns-result collected)
  cache["pool"] = connection-pool (still alive)
  cache["dns"]  = nil (collected)

2. Weak Keys for Identity Tracking (__mode = "k")
------------------------------------------------------------
Pattern: attach metadata to objects without preventing GC.
Used by Kong for request contexts, lazy.nvim for plugin state.

  Before GC: tracking 2 objects
  After GC:  tracking 1 objects (auth-jwt collected)
  rate-limiter metadata: calls=42

3. Ephemeral Associations (__mode = "kv")
------------------------------------------------------------
Pattern: both keys and values weakly held.
Used by APISIX for transient route-to-upstream mappings.

  Before GC: 1 associations
  route -> upstream: backend-1.local:8080
  After dropping upstream + GC: 0 associations
  Entry collected (value was the only weak ref needed)

4. String Key Misuse (ANTI-PATTERN)
------------------------------------------------------------
Strings are interned in Lua and never garbage-collected.
Weak-key tables with string keys NEVER release entries.

  Before GC: 3 entries with string keys
  After GC:  3 entries (strings are NEVER collected)
  All 3 entries remain: interned strings have infinite lifetime.

5. Memoization Cache with Weak Values
------------------------------------------------------------
Pattern: cache computed results; allow GC under memory pressure.
Results are tables (reference types) so weak refs work.

  Computed: alpha=210, beta=168
  Cache entries: 2
  Cache hit for alpha: true
  After dropping beta ref + GC: 1 cache entries
  memo["alpha"] still alive: true (external ref kept)
  memo["beta"] collected: true

6. Object Metadata Without Preventing GC
------------------------------------------------------------
Pattern: attach debug/profiling info to objects via weak-key table.
When the object is collected, metadata is automatically cleaned up.

  Inside scope: 2 objects tracked
  After scope exit + GC: 1 objects tracked
  Survivor metadata: tag=handler-main
  Request metadata: automatically cleaned up by GC.

============================================================
Summary of Weak Table Modes
============================================================

  Mode         Weak Reference       Use Case
  ------------ -------------------- ------------------------
  __mode="v"   Values only          Caches, memoization
  __mode="k"   Keys only            Identity tracking
  __mode="kv"  Keys and values      Ephemeral mappings

  Caveat: string/number/boolean keys are never collected (interned).
  Always use table keys for weak-key tables.
```
