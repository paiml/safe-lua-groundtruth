# Performance Profiling

Compares safe versus unsafe Lua patterns using `safe.perf` and reports timing,
speedup ratios, and memory allocation estimates.
Demonstrates why the safe patterns exist by quantifying the performance difference.

## Key Patterns

- **Benchmark harness**: `time_it` function with GC collection before each measurement
- **String concatenation**: `perf.concat_safe` (table.concat) vs `perf.concat_unsafe` (loop concat)
- **Iteration**: `perf.numeric_for_sum` vs `perf.ipairs_sum`
- **Table reuse**: `perf.reuse_table` vs fresh allocation
- **GC pressure**: Manual `collectgarbage` snapshots to measure allocation impact

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-605 | `perf.concat_safe` vs `perf.concat_unsafe` — quantifies the O(n) vs O(n^2) difference |
| CB-601 | `validate.check_range` validates iteration count input |

## Source

```lua
{{#include ../../../examples/profiling.lua}}
```

## Sample Output

```
Performance Profile (100 iterations)
==================================================

String Concatenation (1000 parts)
--------------------------------------------------
  table.concat (safe)         1.3 ms
  loop concat (unsafe)       18.0 ms
  --> table.concat (safe) is 13.5x faster

Array Sum (10000 elements)
--------------------------------------------------
  numeric for                 9.0 ms
  ipairs                     22.2 ms
  --> numeric for is 2.5x faster

Table Fill (1000 elements)
--------------------------------------------------
  reuse_table                 2.9 ms
  new alloc each time         1.5 ms
  --> new alloc each time is 1.9x faster

GC Snapshot
--------------------------------------------------
  Before allocation:  354.4 KB
  After 10k tables:   1704.2 KB
  Delta:              1349.8 KB
  After GC collect:   610.5 KB
```
