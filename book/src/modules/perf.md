# safe.perf

Performance patterns demonstrating Lua 5.1 best practices. Includes both gold-standard
patterns and intentional anti-patterns for benchmarking comparison.

```lua
local perf = require("safe.perf")
```

## Source

```lua
--[[
  perf.lua — Performance patterns demonstrating Lua 5.1 best practices.
  Local caching, table.concat, pre-allocation, numeric for.
]]

local M = {}

local table_concat = table.concat
local string_rep = string.rep
local string_format = string.format

--- Gold-standard string building: accumulate in table, join with table.concat.
--- @param parts table array of strings
--- @return string
function M.concat_safe(parts)
    return table_concat(parts)
end

--- ANTI-PATTERN: string concatenation in a loop.
--- Intentionally triggers CB-605. Included only for benchmarking comparison.
--- DO NOT use this pattern in production code.
--- @param parts table array of strings
--- @return string
function M.concat_unsafe(parts) -- pmat:ignore CB-605
    local result = ""
    for i = 1, #parts do
        result = result .. parts[i] -- pmat:ignore CB-605
    end
    return result
end

--- Build a repeated string using string.rep (no loop concat).
--- @param n number repetitions
--- @param char string character or substring to repeat
--- @return string
function M.build_string(n, char)
    return string_rep(char, n)
end

--- Sum array elements using numeric for (fastest iteration).
--- @param tbl table array of numbers
--- @return number sum
function M.numeric_for_sum(tbl)
    local sum = 0
    for i = 1, #tbl do
        sum = sum + tbl[i]
    end
    return sum
end

--- Sum array elements using ipairs (comparison).
--- @param tbl table array of numbers
--- @return number sum
function M.ipairs_sum(tbl)
    local sum = 0
    for _, v in ipairs(tbl) do
        sum = sum + v
    end
    return sum
end

--- Clear and refill a table for GC-friendly reuse.
--- @param tbl table table to reuse
--- @param n number number of elements to fill
--- @return table the same table, filled with 1..n
function M.reuse_table(tbl, n)
    -- Clear all entries (numeric and hash keys)
    for k in pairs(tbl) do
        tbl[k] = nil
    end
    -- Refill
    for i = 1, n do
        tbl[i] = i
    end
    return tbl
end

--- Format many items using cached string.format.
--- @param template string format template
--- @param items table array of values
--- @return table array of formatted strings
function M.format_many(template, items)
    local results = {}
    for i = 1, #items do
        results[i] = string_format(template, items[i])
    end
    return results
end

return M
```

## Functions

### `perf.concat_safe(parts)` — Gold Standard

Accumulates strings in a table and joins with `table.concat`. This is O(n) total
allocation instead of O(n^2) from repeated concatenation.

```lua
local parts = {}
for i = 1, 1000 do
    parts[i] = "x"
end
local result = perf.concat_safe(parts)
```

### `perf.concat_unsafe(parts)` — Anti-Pattern

String concatenation in a loop using `..`. Each concatenation creates a new string,
leading to O(n^2) allocation. **Included only for benchmarking comparison** (CB-605).

### `perf.build_string(n, char)`

Uses `string.rep` instead of loop concatenation:

```lua
perf.build_string(100, "=")  --> "==...==" (100 chars)
```

### `perf.numeric_for_sum(tbl)` vs `perf.ipairs_sum(tbl)`

Numeric `for` is faster than `ipairs` because it avoids the overhead of a function call per iteration:

```lua
local data = {1, 2, 3, 4, 5}
perf.numeric_for_sum(data)  --> 15
perf.ipairs_sum(data)       --> 15  (same result, slightly slower)
```

### `perf.reuse_table(tbl, n)`

Clears and refills a table in-place for GC-friendly reuse. Uses `pairs()` to clear both numeric and hash keys:

```lua
local buffer = {}
perf.reuse_table(buffer, 1000)
-- buffer now contains {1, 2, 3, ..., 1000}
-- reuse avoids creating a new table each time
```

### `perf.format_many(template, items)`

Applies `string.format` to each item using a cached local reference:

```lua
perf.format_many("item_%d", {1, 2, 3})
--> {"item_1", "item_2", "item_3"}
```

## Performance Comparison

See the [Benchmarks](../benchmarks.md) chapter for quantitative results. Key findings:

- `concat_safe` vs `concat_unsafe`: 10-100x faster at scale (n=10000)
- `numeric_for_sum` vs `ipairs_sum`: ~10-20% faster
- `reuse_table` vs new table: reduces GC pressure, comparable speed

## Known Limitations

- **`concat_safe` input constraints**: `table.concat` requires all elements to be
  strings or numbers. It errors on `nil`, `boolean`, or `table` elements.
- **`concat_unsafe` with holes**: Arrays with nil holes have undefined `#` length,
  leading to unpredictable behavior.
- **`numeric_for_sum` with nil holes**: If `#tbl` reports a length that includes a
  nil slot, `sum + nil` errors.
- **`format_many` type mismatch**: If the format specifier doesn't match the item type
  (e.g., `%d` with a string), `string.format` throws.
