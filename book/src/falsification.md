# Falsification Findings

The falsification suite (`spec/falsify_spec.lua`) contains 56 adversarial tests that probe specification weaknesses, boundary conditions, and semantic edge cases. These tests were written after the initial implementation to find bugs and document known limitations.

Five bugs were found and fixed. The remaining findings are documented behaviors.

## Bugs Fixed

| Module | Bug | Fix |
|--------|-----|-----|
| validate | `check_range` accepted NaN (NaN fails all comparisons silently) | Added explicit `value ~= value` NaN check |
| shell | `validate_program` allowed newlines, tabs, spaces in program names | Added `%s` (whitespace) to metacharacter pattern |
| perf | `reuse_table` only cleared numeric keys (used `for i = 1, #tbl`) | Changed to `for k in pairs(tbl)` to clear hash keys too |
| log | `with_context` didn't restore context on output function error | Wrapped `emit` in `pcall`, restoring context in all paths |
| shell | `validate_program` allowed double and single quotes | Added `"'` to metacharacter character class |

## guard.lua Findings

### Shallow Freeze

`guard.freeze()` creates a read-only proxy via `__newindex`, but the protection is shallow. Nested tables accessed through the proxy are fully mutable:

```lua
local inner = { value = 1 }
local frozen = guard.freeze({ nested = inner })
frozen.nested.value = 999  -- succeeds! inner.value is now 999
```

This is inherent to the proxy pattern — `__newindex` only fires on direct assignment to the proxy table, not on nested access.

### No `pairs()` Iteration in Lua 5.1

The frozen proxy is an empty table with `__index` pointing to the original. In Lua 5.1, `pairs()` iterates the proxy's own keys (none), not the underlying table. Lua 5.2+ supports `__pairs` metamethod, but 5.1 does not.

```lua
local frozen = guard.freeze({ a = 1, b = 2, c = 3 })
for k in pairs(frozen) do print(k) end  -- prints nothing
```

### `rawget` Bypass

`rawget(frozen, key)` bypasses `__index` and reads from the empty proxy, returning nil.

### `protect_globals` Replaces Metatables

Any existing metatable on the environment is silently overwritten. There is no merge or chain behavior.

### Lua Truthiness in `contract`

`guard.contract(0, msg)` passes — `0` is truthy in Lua (unlike C/Python). Same for empty string.

### Duplicate Enum Names

`guard.enum({"A", "B", "A"})` silently deduplicates. Since each name maps to itself, the duplicate write is idempotent.

## log.lua Findings

### Context Restoration on Error

**Fixed.** `with_context` now wraps `emit` in `pcall` to ensure the parent context is restored even when the output function throws.

### Format String Edge Cases

- Literal `%` without varargs is safe — when no extra args are passed, the format string is used as-is (no `string.format` call).
- Wrong argument count (e.g., `"%s %s"` with one arg) propagates the `string.format` error.

### Module State is Shared

All `require("safe.log")` calls return the same table. Level and context changes are globally visible. This is by design (Lua module caching) but can surprise users.

## validate.lua Findings

### NaN Rejection

**Fixed.** `check_range` now explicitly checks `value ~= value` (the IEEE 754 NaN identity test) before the range comparison. Without this, NaN silently passed all range checks because `NaN < min` and `NaN > max` are both false.

### Infinity Handling

`math.huge` (positive infinity) and `-math.huge` correctly fail range checks via normal `<`/`>` comparison.

### `false` as Default Value

`schema` uses `spec.default ~= nil` to check for defaults, so `false` works correctly as a default value. This is deliberate — a `nil` check rather than a truthiness check.

### Required + Default Precedence

When both `required = true` and `default` are set, the default branch is checked first. If the field is absent, the default is applied and the required check never fires.

### Schema Error Ordering

Multiple schema validation errors are collected via `pairs()` iteration, so their order is nondeterministic (depends on Lua's hash table implementation).

### Floating-Point Boundaries

`check_range` uses `<` and `>` comparison. At the boundary, floating-point representation determines whether a value like `1 - 1e-15` is inside or outside the range.

## shell.lua Findings

### Whitespace and Quote Injection

**Fixed.** `validate_program` now rejects newlines, tabs, carriage returns, spaces, and quotes in program names. The metacharacter character class includes `%s` (all whitespace), `"`, and `'`.

### Null Byte Passthrough

`shell.escape("a\0b")` includes the null byte inside single quotes. This is potentially dangerous — behavior varies by shell implementation.

### `validate_args` Ignores Hash Keys

The numeric `for` loop only checks indices `1..#args`. Non-sequential keys like `{ "a", extra = "ignored" }` are silently skipped.

### Escaping Is the Safety Layer

`build_command` validates the program name but **does not validate argument content**. Arguments can contain arbitrary data including `; rm -rf /` — safety comes from single-quote escaping, not validation.

### `_normalize_exit` Edge Cases

`nil` as a return value from `os.execute` is mapped to `false, 1`.

## perf.lua Findings

### Table Clearing

**Fixed.** `reuse_table` now uses `for k in pairs(tbl)` instead of `for i = 1, #tbl` to clear both numeric indices and hash keys.

### Non-String Elements in concat

- `table.concat` coerces numbers to strings but errors on `nil`, `boolean`, or `table` elements.
- The `..` operator in `concat_unsafe` also coerces numbers but errors on other types.

### Nil Holes

Arrays with nil holes have undefined `#` length in Lua. Both `numeric_for_sum` and `concat_unsafe` exhibit unpredictable behavior with such arrays.

## test_helpers.lua Findings

### NaN in `table_eq`

`table_eq` uses `a == b` for leaf comparison. Since `NaN ~= NaN` per IEEE 754, tables containing NaN are never considered equal — not even to themselves:

```lua
local nan = 0/0
helpers.table_eq(nan, nan)               --> false
helpers.table_eq({ x = nan }, { x = nan }) --> false
```

### Cyclic Table Handling

`table_eq` uses a `seen` table for cycle detection. Self-referencing and mutually-referencing structures are handled without infinite recursion.

### Metatables Ignored

`table_eq` compares data via `pairs()` and raw equality. Custom `__eq` metamethods have no effect.

### `capture_output` Mock Limitations

The mock `io.write` replacement doesn't return the file handle, so `io.write("a"):write("b")` chaining breaks under capture.

### Shared Mutable State in Mocks

The `calls` tracker returned by `mock_executor` and `mock_popen` is a direct reference, not a copy. Callers can mutate it.

### Text-Mode File Writing

`with_temp_file` opens files with `"w"` (text mode). On Windows, `\r\n` translation may alter binary content.

### Non-String Error Objects

`assert_errors` uses `tostring(err)` for pattern matching. Table error objects produce `"table: 0x..."` which won't match meaningful patterns.
