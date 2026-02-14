# PMAT Compliance

Walks through all 8 CB checks (CB-600 through CB-607) in a single script, demonstrating each defensive pattern and printing a pass/fail matrix.

## CB Checks Demonstrated

| Check | Pattern | safe-lua API |
|-------|---------|--------------|
| CB-600 | Implicit globals | `guard.protect_globals` |
| CB-601 | Nil-safe access | `guard.safe_get` |
| CB-602 | pcall handling | `pcall` + error propagation |
| CB-603 | Dangerous APIs | `shell.validate_program`, `shell.escape` |
| CB-604 | Unused variables | `_` prefix convention |
| CB-605 | String concat | `perf.concat_safe` |
| CB-606 | Module return | `type(mod) == "table"` check |
| CB-607 | Colon/dot syntax | `validate.Checker` colon methods |

## Source

```lua
{{#include ../../../examples/compliance.lua}}
```

## Sample Output

```
PMAT CB-600 Compliance Matrix
============================================================

Check     Status  Description
------------------------------------------------------------
CB-600    PASS    Implicit globals
CB-601    PASS    Nil-safe access
CB-602    PASS    pcall error handling
CB-603    PASS    Safe shell execution
CB-604    PASS    Unused variables (static lint)
CB-605    PASS    String concat (table.concat)
CB-606    PASS    Module return value
CB-607    PASS    Colon/dot syntax
------------------------------------------------------------
Result: 8/8 checks passed
```
