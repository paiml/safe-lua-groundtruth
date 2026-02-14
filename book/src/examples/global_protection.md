# Global Protection

Lua 5.1 has a single mutable global table (`_G`) shared
by all code. Any module or script can accidentally
overwrite a global, silently shadowing a standard library
function or leaking internal state. This is a major
source of bugs in large Lua codebases.

This example demonstrates six real-world patterns for
protecting global state, drawn from top Lua projects:
lite-xl, AwesomeWM, Kong, and safe-lua itself.

## Why Globals Are Dangerous

1. **Silent overwrites**: `string = nil` silently breaks
   every `string.format` call in the entire process.
2. **Typo propagation**: `reuslt = compute()` creates a
   new global instead of raising an error.
3. **Sandbox escapes**: Untrusted code with access to
   `_G` can reach `os.execute`, `io.popen`, and
   `loadstring`.
4. **Test pollution**: A test that sets a global leaks
   state into subsequent tests.

## Patterns Demonstrated

| # | Pattern | Origin | Reads | Writes |
|---|---------|--------|-------|--------|
| 1 | Strict mode | lite-xl | Blocked | Blocked |
| 2 | `__newindex = error` | AwesomeWM | nil (defect) | Blocked |
| 3 | Complete freeze | Manual | Blocked | Blocked |
| 4 | Sandbox whitelist | Kong | Blocked | Blocked |
| 5 | `guard.protect_globals` | safe-lua | Blocked | Blocked |
| 6 | `guard.freeze` | safe-lua | Allowed | Blocked |

Pattern 2 is deliberately shown as a **defective**
example: it blocks writes but silently returns `nil` for
reads of nonexistent keys. Pattern 3 shows the fix.

## Key Takeaways

- **Always protect both directions.** A write-only
  freeze still lets typos through as silent `nil` reads.
- **Sandbox by whitelist, not blacklist.** Kong's pattern
  starts with an empty table and adds only safe
  functions.
- **Use `guard.protect_globals`** for strict-mode
  enforcement with automatic key snapshotting.
- **Freeze config tables** with `guard.freeze()` so
  downstream consumers cannot mutate shared state.

## Source

```lua
{{#include ../../../examples/global_protection.lua}}
```

## Sample Output

```text
Global Protection & Sandboxing Patterns
============================================================
Six patterns from lite-xl, AwesomeWM, Kong, and safe-lua.

------------------------------------------------------------
Pattern: 1. Strict Mode (lite-xl)
------------------------------------------------------------
  Undeclared write blocked: true
    Error: ...cannot set undefined variable: foo
  Undeclared read blocked:  true
    Error: ...cannot get undefined variable: bar
  Declared global 'counter': 10
  Declared nil read 'optional': nil

------------------------------------------------------------
Pattern: 2. Write-only Freeze (AwesomeWM __newindex = error)
------------------------------------------------------------
  Write blocked:  true
  Read x:         1
  Read missing:   nil  (silent nil — defect!)

------------------------------------------------------------
Pattern: 3. Complete Freeze (__index + __newindex)
------------------------------------------------------------
  Read x:          1
  Write blocked:   true
    Error: ...write to frozen key: x
  Unknown read blocked: true
    Error: ...read of unknown key: nonexistent

------------------------------------------------------------
Pattern: 4. Sandbox Environment (Kong)
------------------------------------------------------------
  Safe code OK:       true
  Result:             answer = 42
  Dangerous code OK:  false
    Error: ...attempt to index global 'os' (a nil value)
  require() blocked:  true
    Error: ...attempt to call global 'require' (a nil value)

------------------------------------------------------------
Pattern: 5. guard.protect_globals (safe-lua)
------------------------------------------------------------
  config_mode:  production
  max_retries:  3
  Undeclared write blocked: true
    Error: ...assignment to undeclared global: new_thing
  Undeclared read blocked:  true
    Error: ...access to undeclared global: nonexistent
  Updated max_retries:  5

------------------------------------------------------------
Pattern: 6. Read-only Configuration Table
------------------------------------------------------------
  host:        api.example.com
  port:        443
  timeout_ms:  5000
  tls_enabled: true
  Write blocked:    true
    Error: ...attempt to modify frozen table key: port
  Port unchanged:   443

============================================================
Protection Summary Matrix
============================================================

Pattern                              Reads    Writes   Source
------------------------------------------------------------
1. Strict mode (lite-xl)             BLOCKS   BLOCKS   lite-xl
2. __newindex = error (AwesomeWM)    nil      BLOCKS   awesome
3. Complete freeze (__index+__ni)    BLOCKS   BLOCKS   manual
4. Sandbox whitelist (Kong)          BLOCKS   BLOCKS   kong
5. guard.protect_globals             BLOCKS   BLOCKS   safe-lua
6. guard.freeze (read-only)          ALLOWS   BLOCKS   safe-lua
------------------------------------------------------------

BLOCKS = errors on access
ALLOWS = returns value (or nil for missing keys)
nil    = silently returns nil (defect)

Done.
```

## Real-World Project Mapping

| Project | Pattern Used | Notes |
|---------|-------------|-------|
| lite-xl | Strict mode | `core.strict` module |
| AwesomeWM | `__newindex = error` | Partial freeze only |
| Kong | Sandbox whitelist | PDK sandbox for plugins |
| KOReader | Strict + env | `require("dbg").guard` |
| xmake | Protected env | Build sandbox isolation |
| safe-lua | `guard.protect_globals` | Snapshot-based strict |
| safe-lua | `guard.freeze` | Read-only proxy tables |
