# String Building

String concatenation in Lua is deceptively expensive.
Because Lua strings are immutable and interned, every
`..` creates a brand-new string object. A loop that
accumulates via `result = result .. piece` copies the
entire result so far on each iteration, producing
O(n^2) total bytes allocated. This is the single most
common performance bug in Lua codebases (CB-605).

Every major Lua project -- Kong, APISIX, KOReader,
lite-xl, xmake -- uses the same fix: collect parts in
a table, then call `table.concat` once at the end.
This example demonstrates the anti-pattern, the fix,
and six additional string-building idioms found across
top Lua projects.

## Patterns Covered

| # | Pattern | Complexity |
|---|---------|------------|
| 1 | Accumulator anti-pattern | O(n^2) |
| 2 | `table.concat` | O(n) |
| 3 | `string.format` (cached) | O(n) |
| 4 | `perf.concat_safe` vs `unsafe` | O(n) vs O(n^2) |
| 5 | Benchmark comparison | -- |
| 6 | Serialization (KOReader dump) | O(n) |
| 7 | Single concat (false positive) | O(n) |

## Why It Matters

At N=1000 the accumulator is already 10-40x slower
than `table.concat`. At N=10000 the gap widens to
50-300x. The `perf.concat_unsafe` function wraps the
same anti-pattern using `string.format("%s%s", ...)`,
which is even slower due to format parsing overhead.

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-605 | Accumulator anti-pattern vs `table.concat` |
| CB-601 | `guard.assert_type` on all function inputs |
| CB-600 | `guard.contract` verifying result correctness |

## Source

```lua
{{#include ../../../examples/string_building.lua}}
```

## Sample Output

```text
String Building Patterns
============================================================

1. Accumulator Anti-Pattern (O(n^2) -- CB-605)
------------------------------------------------------------
  BAD:  result = result .. items[i]  -- each iteration
        copies the entire string so far, leading to
        O(n^2) total allocations.
  Demo (5 items): "item_0001item_0002item_0003...item_0005"

2. table.concat (O(n) -- universal fix)
------------------------------------------------------------
  GOOD: Collect parts in a table, join once.
  Plain:     "item_0001item_0002item_0003...item_0005"
  Separator: "item_0001, item_0002, ..., item_0005"

3. string.format (Kong/APISIX pattern)
------------------------------------------------------------
  Cache as: local fmt = string.format
error in router at line 42: no upstream
error in auth at line 87: token expired
error in proxy at line 15: timeout

4. perf.concat_safe vs perf.concat_unsafe
------------------------------------------------------------
  safe   len: 90
  unsafe len: 90
  Results match: true

5. Benchmark Comparison
------------------------------------------------------------
  Method                         N       Time     Length
  ----------------------------------------------------------
  accumulator (O(n^2))        1000   55.67 ms       9000
  table.concat (O(n))         1000    4.84 ms       9000
  perf.concat_safe             1000    1.39 ms       9000
  perf.concat_unsafe           1000   59.95 ms       9000

  accumulator (O(n^2))       10000  392.48 ms      90001
  table.concat (O(n))        10000    5.79 ms      90001
  perf.concat_safe            10000    1.38 ms      90001
  perf.concat_unsafe          10000  435.89 ms      90001

6. Serialization Pattern (KOReader dump)
------------------------------------------------------------
  Insert parts into table, join with table.concat:

{
  "host": "127.0.0.1",
  "port": "8080",
  "proto": "https",
}

7. Single Concat Per Iteration (NOT a problem)
------------------------------------------------------------
  A single '..' per loop body is O(n), not O(n^2).
  Each iteration produces an independent string;
  no accumulator grows across iterations.

  Processing: alpha
  Processing: bravo
  Processing: charlie

============================================================
```

## Benchmark Results

Timings from a single run (100 iterations at N=1000,
10 iterations at N=10000). Actual numbers vary by
machine, but the ratios are consistent.

| Method | N=1000 | N=10000 | Complexity |
|--------|--------|---------|------------|
| `table.concat` | ~5 ms | ~6 ms | O(n) |
| `perf.concat_safe` | ~1 ms | ~1 ms | O(n) |
| accumulator `..` | ~56 ms | ~392 ms | O(n^2) |
| `perf.concat_unsafe` | ~60 ms | ~436 ms | O(n^2) |

The quadratic methods scale roughly with n^2: doubling
N from 1000 to 10000 increases time by ~7x (expected
~10x, offset by constant factors). The linear methods
barely change because `table.concat` is a single C
call over a pre-built array.
