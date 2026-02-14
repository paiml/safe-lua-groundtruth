# Vararg Patterns

Lua 5.1's variadic functions (`...`) have subtle gotchas that
bite even experienced developers. The `#` operator on `{...}`
is undefined when the table contains nil holes, `ipairs` stops
at the first nil, and `unpack` without an explicit length
silently drops trailing nils. These are not edge cases --- they
are the default behavior.

This example demonstrates seven battle-tested idioms drawn from
AwesomeWM `gears.table.join`, APISIX `core.table.insert_tail`,
lite-xl, and xmake that correctly handle variadic arguments
with nil holes, safe forwarding, and argument overloading.

## Key Patterns

- **`safe_pack(...)`**: Lua 5.1 has no `table.pack`. The naive
  `{...}` loses trailing nils because `#` is undefined for
  tables with holes. `select("#", ...)` correctly counts ALL
  arguments, so `{n = select("#", ...), ...}` preserves them.
- **`safe_unpack(packed)`**: `unpack(t)` stops at the first nil
  hole. Passing the explicit length `unpack(t, 1, t.n)` returns
  all positions including nil ones.
- **`vararg_iterate(fn, ...)`**: `ipairs({...})` stops at the
  first nil. A `for i = 1, select("#", ...) do` loop visits
  every position via `select(i, ...)`.
- **`insert_tail(t, ...)`**: APISIX pattern to append multiple
  values to an array using `select` iteration over varargs.
- **`join_arrays(...)`**: AwesomeWM pattern to concatenate N
  arrays passed as varargs into a single new array.
- **Argument overloading**: Dispatch on `type(...)` and
  `select("#", ...)` to support multiple call signatures from
  a single function, a common Lua API flexibility idiom.
- **`forward_varargs(fn, ...)`**: Pack-then-unpack to safely
  forward all arguments (including trailing nils) to another
  function.

## CB Checks Demonstrated

| Check  | Where                                             |
|--------|---------------------------------------------------|
| CB-601 | `guard.assert_type` on all function arguments     |
| CB-601 | `guard.assert_not_nil` on packed.n field           |
| CB-600 | `guard.contract` for invariant assertions          |
| CB-607 | `validate.Checker` colon-syntax in overloaded fn   |

## Source

```lua
{{#include ../../../examples/vararg_patterns.lua}}
```

## Sample Output

```text
Variadic Function Idioms in Lua 5.1
============================================================
Patterns from AwesomeWM, APISIX, lite-xl, and xmake.

============================================================
  Pattern 1-2: safe_pack / safe_unpack
============================================================

--- Trailing nil preservation ---
  Lua 5.1 gotcha: {1, nil, 3, nil} has # == 1 or 3 (undefined)
  select('#', 1, nil, 3, nil) always returns 4

  naive {1,nil,'three',nil}:  # = 1
  safe_pack(1,nil,'three',nil): n = 4
--- Round-trip via safe_unpack ---
  a=1  b=nil  c=three  d=nil

  safe_pack():  n = 0
  safe_pack(nil): n = 1

============================================================
  Pattern 3: vararg_iterate
============================================================

--- ipairs vs select loop with nil holes ---
  ipairs({...}) visits:
    [1] = a
  ipairs saw 1 elements (stops at first nil)

  vararg_iterate visits:
    [1] = a
    [2] = nil
    [3] = c
    [4] = nil
    [5] = e
  select loop saw 5 elements (all positions)

============================================================
  Pattern 4-5: insert_tail and join_arrays
============================================================

--- insert_tail (APISIX pattern) ---
  after insert_tail: {existing, alpha, beta, gamma}
  insert_tail({}, 1, nil, 3): #t2 = 2
    t2[1]=1  t2[2]=3  t2[3]=nil

--- join_arrays (AwesomeWM pattern) ---
  join_arrays({1,2,3}, {4,5}, {6,7,8}) = {1, 2, 3, 4, 5, 6, 7, 8}
  join_arrays({}, {1,2,3}, {}, {4,5}, {}) = 5 elements

============================================================
  Pattern 6: Argument Overloading
============================================================

--- Dispatch by type and count ---
  overloaded('users')         = lookup(users)
  overloaded('users', 10)     = lookup(users, limit=10)
  overloaded({name, role})    = batch_lookup({name, role})

  overloaded(42):  ok=false
    error: unsupported call: argc=1, type=number
  overloaded('users', 'not-a-number'): ok=false
    error: expected limit to be number, got string

============================================================
  Pattern 7: Safe Vararg Forwarding
============================================================

--- Forwarding preserves trailing nils ---
  direct call:    a=x b=nil c=z (argc via method=3)
  forwarded call: a=x b=nil c=z (argc via method=3)
--- Forwarding with all-nil arguments ---
  all-nil forwarded: a=nil b=nil c=nil (argc via method=3)
--- Round-trip count verification ---
  forward_varargs(count_args, 1, nil, 3, nil) = 4
  forward_varargs(count_args) = 0
  forward_varargs(count_args, nil) = 1

============================================================
Vararg Pattern Reference
============================================================

  Function                 Description                  Origin
  ------------------------ ---------------------------- ----------------
  safe_pack(...)           Nil-safe pack with n field   AwesomeWM, xmake
  safe_unpack(t)           Unpack with explicit n       AwesomeWM, xmake
  vararg_iterate(fn,...)   Iterate all positions        lite-xl
  insert_tail(t,...)       Append multiple values       APISIX
  join_arrays(...)         Join N arrays into one       AwesomeWM
  overloaded_function      Type/count dispatch          lite-xl, xmake
  forward_varargs(fn,...)  Safe nil-preserving forward  General
```

## Pattern Reference

| Pattern              | Source Project           | Technique                    |
|----------------------|--------------------------|------------------------------|
| safe_pack            | AwesomeWM, xmake         | `select("#", ...)` + n field |
| safe_unpack          | AwesomeWM, xmake         | `unpack(t, 1, t.n)`         |
| vararg_iterate       | lite-xl                  | Counted `select(i, ...)` loop|
| insert_tail          | APISIX core.table        | Append via select iteration  |
| join_arrays          | AwesomeWM gears.table    | Outer select + inner ipairs  |
| Argument overloading | lite-xl, xmake           | Type + count dispatch        |
| forward_varargs      | General Lua idiom        | Pack-unpack round-trip       |
