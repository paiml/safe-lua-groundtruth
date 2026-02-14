# Table Operations

Table utility patterns drawn from the Lua ecosystem, specifically
AwesomeWM's `gears.table` module and APISIX's `core.table` module.
These functions solve recurring problems in every non-trivial Lua
codebase: copying tables without shared-reference surprises,
merging configuration layers, searching arrays, safely traversing
nested structures, and compacting sparse arrays.

Every function validates its inputs with `guard.assert_type` and
results are cross-checked with `guard.contract` and
`validate.Checker` to demonstrate defensive programming throughout.

## Key Patterns

- **shallow_copy(t)**: Copy a table's top-level entries; nested tables remain shared references
- **deep_clone(t, seen)**: Recursively clone with a `seen` table for cycle detection
- **crush(target, source)**: Merge source into target, overwriting existing keys (config layering)
- **join(...)**: Concatenate multiple arrays into one new array via varargs with `select("#", ...)`
- **keys(t)**: Extract and sort all keys from a table
- **values(t)**: Extract all values from a table
- **array_find(t, value)**: Linear search for the first index of a value, returns nil on miss
- **safe_nested_get(t, ...)**: Variadic nil-safe nested access, returns nil at first missing key
- **reverse(t)**: Reverse an array in-place using index swapping
- **from_sparse(t)**: Compact a sparse array by removing nil holes via manual max-key scan
- **count_keys(t)**: Count all keys (integer and string) by iterating with `pairs`

## CB Checks Demonstrated

| Check  | Where                                          |
|--------|-------------------------------------------------|
| CB-601 | `guard.assert_type` on every function input     |
| CB-601 | `safe_nested_get` returns nil instead of erroring |
| CB-600 | `guard.contract` validates postconditions       |
| CB-606 | All functions return values, no global mutation  |
| CB-607 | `validate.Checker` colon-syntax for config check |

## Source

```lua
{{#include ../../../examples/table_operations.lua}}
```

## Sample Output

```text
Table Operations — Utility Patterns from the Lua Ecosystem
============================================================
Patterns from AwesomeWM gears.table and APISIX core.table.

1. Shallow Copy vs. Deep Clone
------------------------------------------------------------
shallow_copy shares nested references; deep_clone does not.

  original.tags[1] = MODIFIED  (shared — also modified!)
  shallow.tags[1]  = MODIFIED  (modified)
  same tags table? true

  original.tags[1]         = MODIFIED  (unchanged by deep clone)
  deep.tags[1]             = DEEP
  original.meta.nested.level = 3  (unchanged)
  deep.meta.nested.level     = 99
  same meta table? false

  Cycle detection:
    cyclic.self == cyclic:       true
    cloned.self == cloned:       true  (cycle preserved)
    cloned.self == cyclic:       false  (independent copy)

2. Crush (Merge) and Join
------------------------------------------------------------
crush overwrites target keys; join concatenates arrays.

  defaults:  {debug=false, host=localhost, port=8080, timeout=30}
  overrides: {debug=true, port=443, tls=true}
  merged:    {debug=true, host=localhost, port=443, timeout=30, tls=true}

  a = {1, 2, 3}
  b = {4, 5}
  c = {6, 7, 8, 9}
  join(a, b, c) = {1, 2, 3, 4, 5, 6, 7, 8, 9}
  join({}, a, {}, b, {}) = {1, 2, 3, 4, 5}

3. Search and Access
------------------------------------------------------------
keys, values, array_find, safe_nested_get.

  config keys (sorted): {host, port, retries, timeout}
  config values (4 total): ...

  fruits = {apple, banana, cherry, date, elderberry}
  array_find(fruits, 'cherry') = 3
  array_find(fruits, 'grape')  = nil

  safe_nested_get:
    deep.server.database.primary.host = db1.internal
    deep.server.cache.redis.host      = nil  (missing path)
    safe_nested_get(nil, 'a', 'b')    = nil  (nil root)

4. Array Transforms
------------------------------------------------------------
reverse, from_sparse, count_keys.

  before reverse: {1, 2, 3, 4, 5}
  after reverse:  {5, 4, 3, 2, 1}
  reverse {a,b,c,d}: {d, c, b, a}

  from_sparse:
    sparse indices: 1, 3, 5, 8
    sparse values:  alpha, nil, charlie, nil, echo, nil, nil, hotel
    compacted: {alpha, charlie, echo, hotel}  (4 elements)

  count_keys:
    table with 3 string keys + 2 integer keys: 5 total
    empty table: 0 keys

5. Error Handling
------------------------------------------------------------
guard.assert_type catches invalid inputs to table utilities.

  shallow_copy('not a table'): ok=false
    error: ...expected t to be table, got string
  join({1,2}, 42):             ok=false
    error: ...expected arg[2] to be table, got number
  keys(nil):                   ok=false
    error: ...expected t to be table, got nil

  Checker on merged config: ok=true, errors=0

============================================================
Table Utility Function Reference
============================================================

  Function                 Description                    Origin
  ------------------------ ------------------------------ ----------
  shallow_copy(t)          Shallow copy (shared refs)     AwesomeWM
  deep_clone(t)            Deep copy + cycle detection    AwesomeWM
  crush(target, src)       Merge src into target          AwesomeWM
  join(...)                Concatenate arrays             AwesomeWM
  keys(t)                  Sorted key array               AwesomeWM
  values(t)                Value array                    AwesomeWM
  array_find(t, v)         First index of value           APISIX
  safe_nested_get(t,...)   Nil-safe nested access         APISIX
  reverse(t)               Reverse array in-place         AwesomeWM
  from_sparse(t)           Compact sparse array           AwesomeWM
  count_keys(t)            Count all keys                 AwesomeWM
```

## Pattern Reference

| Function | Source Project | Pattern |
|----------|--------------|---------|
| `shallow_copy` | AwesomeWM `gears.table.clone` | `pairs` iteration copy |
| `deep_clone` | AwesomeWM `gears.table.clone` | Recursive with `seen` set |
| `crush` | AwesomeWM `gears.table.crush` | In-place key overwrite |
| `join` | AwesomeWM `gears.table.join` | Varargs with `select("#", ...)` |
| `keys` | AwesomeWM `gears.table.keys` | `pairs` + `table.sort` |
| `values` | AwesomeWM `gears.table.values` | `pairs` value extraction |
| `array_find` | APISIX `core.table.array_find` | Linear scan, nil on miss |
| `safe_nested_get` | APISIX `core.table.try_read_attr` | Variadic nil-safe traversal |
| `reverse` | AwesomeWM `gears.table.reverse` | In-place index swap |
| `from_sparse` | AwesomeWM `gears.table.from_sparse` | Manual max-key scan + compact |
| `count_keys` | AwesomeWM `gears.table.count_keys` | `pairs` counter |
