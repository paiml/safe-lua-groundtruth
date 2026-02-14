# Benchmarks

Performance benchmarks comparing safe patterns against anti-patterns at various scales.

## Benchmark Harness

The benchmark harness lives in `benchmarks/perf_bench.lua`:

```lua
#!/usr/bin/env lua5.1
--[[
  perf_bench.lua — Performance benchmarks for safe.perf patterns.
  Compares safe vs unsafe patterns at various scales.

  Usage: lua5.1 benchmarks/perf_bench.lua
]]

package.path = "lib/?.lua;" .. package.path

local perf = require("safe.perf")

local os_clock = os.clock
local string_format = string.format

local function bench(name, n, fn)
    local start = os_clock()
    local iterations = 1000
    for _ = 1, iterations do
        fn()
    end
    local elapsed = os_clock() - start
    local time_ms = elapsed * 1000
    local ops = iterations / elapsed
    io.write(string_format("%s\t%d\t%.3f\t%.0f\n", name, n, time_ms, ops))
end

local function make_parts(n)
    local parts = {}
    for i = 1, n do
        parts[i] = "x"
    end
    return parts
end

local function make_numbers(n)
    local tbl = {}
    for i = 1, n do
        tbl[i] = i
    end
    return tbl
end

io.write("benchmark\tn\ttime_ms\tops_per_sec\n")
io.write(string.rep("-", 60) .. "\n")

-- String concatenation: safe vs unsafe
for _, n in ipairs({ 100, 1000, 10000 }) do
    local parts = make_parts(n)
    bench("concat_safe", n, function()
        perf.concat_safe(parts)
    end)
    bench("concat_unsafe", n, function()
        perf.concat_unsafe(parts)
    end)
end

-- Iteration: numeric for vs ipairs
for _, n in ipairs({ 10000 }) do
    local tbl = make_numbers(n)
    bench("numeric_for_sum", n, function()
        perf.numeric_for_sum(tbl)
    end)
    bench("ipairs_sum", n, function()
        perf.ipairs_sum(tbl)
    end)
end

-- Table reuse vs new table
for _, n in ipairs({ 1000 }) do
    local reuse_tbl = {}
    bench("reuse_table", n, function()
        perf.reuse_table(reuse_tbl, n)
    end)
    bench("new_table", n, function()
        local t = {}
        for i = 1, n do
            t[i] = i
        end
    end)
end

io.write("\nDone.\n")
```

## Running

```bash
make bench
```

## Benchmark Groups

### String Concatenation: `concat_safe` vs `concat_unsafe`

Tests at n=100, n=1000, and n=10000.

- **`concat_safe`** uses `table.concat` — O(n) total allocation
- **`concat_unsafe`** uses `result = result .. parts[i]` — O(n^2) total allocation

At n=100, the difference is small. At n=10000, `concat_safe` is typically **10-100x faster** due to the quadratic cost of repeated string creation in `concat_unsafe`.

### Iteration: `numeric_for_sum` vs `ipairs_sum`

Tests at n=10000.

- **`numeric_for_sum`** uses `for i = 1, #tbl do` — direct index access
- **`ipairs_sum`** uses `for _, v in ipairs(tbl) do` — iterator function overhead

Numeric `for` is typically **10-20% faster** because it avoids the per-iteration function call overhead of `ipairs`.

### Table Reuse: `reuse_table` vs `new_table`

Tests at n=1000.

- **`reuse_table`** clears and refills an existing table
- **`new_table`** allocates a fresh table each iteration

Both have similar raw speed, but `reuse_table` reduces GC pressure by avoiding repeated allocation and collection of short-lived tables.

## Interpreting Results

The harness outputs TSV with columns:

| Column | Meaning |
|--------|---------|
| benchmark | Function name |
| n | Input size |
| time_ms | Total wall time for 1000 iterations (ms) |
| ops_per_sec | Operations per second |

Results vary by hardware and Lua implementation. The relative ratios between safe and unsafe patterns are the meaningful signal, not absolute numbers.
