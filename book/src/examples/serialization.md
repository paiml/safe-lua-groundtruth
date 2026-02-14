# Serialization

Encode/decode and data interchange patterns drawn from KOReader
`dump.lua`/`serialize.lua`, xmake `serialize.lua`, APISIX JSON
patterns, and lite-xl `dkjson.lua`. Demonstrates Lua table
serialization with cycle detection, safe deserialization via
`loadstring` + `setfenv` sandbox, minimal JSON encoding with type
dispatch, and round-trip validation proving serialize/deserialize
fidelity.

## Key Patterns

- **Lua table serializer**: Recursively encodes nil, boolean, number, string (with escape sequences), and tables to valid Lua source. Detects array vs hash tables and formats accordingly.
- **Cycle detection**: Tracks visited tables in a `seen` set; `guard.contract` errors on cycles while allowing shared (non-cyclic) references.
- **String escaping**: Handles `\n`, `\t`, `\\`, `\"`, `\r`, and non-printable chars via `\NNN` byte escapes.
- **Pretty-print**: Configurable indent level; wraps output in `return` prefix to produce a loadable Lua chunk.
- **Safe deserialization**: `loadstring` + `setfenv` to an empty table creates a sandbox that blocks all global access (`os.execute`, `io.open`, etc).
- **JSON encoding**: Type dispatch with `guard.contract` on unsupported types. JSON-specific escapes (`\/`, `\b`, `\f`, `\uNNNN` for control chars).
- **Round-trip validation**: Serialize, deserialize, deep-compare to prove data fidelity.

## CB Checks Demonstrated

| Check  | Where                                              |
|--------|----------------------------------------------------|
| CB-600 | `guard.contract` on cycle detection and JSON types |
| CB-601 | `guard.assert_type` validates string inputs        |
| CB-601 | `guard.contract` on loadstring success             |
| CB-605 | `table_insert` + `table_concat` for string building |
| CB-606 | All functions return values (no global mutation)   |
| CB-607 | `validate.Checker` colon-syntax in round-trip demo |

## Source

```lua
{{#include ../../../examples/serialization.lua}}
```

## Sample Output

```text
Serialization Patterns
============================================================
Encode/decode and data interchange from KOReader,
xmake, APISIX, and lite-xl — with safe-lua
defensive validation.

------------------------------------------------------------
Section: 1. Lua Table Serializer
------------------------------------------------------------
  Compact:
    {enabled = true, config = {retries = 3, ...}, name = "safe-lua", tags = {"lua", ...}, version = 1}
  Pretty (return prefix):
    return {
      enabled = true,
      config = {
        retries = 3,
        timeout = 30,
        verbose = false
      },
      name = "safe-lua",
      tags = {
        "lua",
        "safety",
        "patterns"
      },
      version = 1
    }
  Special values:
    nil:    nil
    true:   true
    42:     42
    string: "hello\nworld"
    empty:  {}

------------------------------------------------------------
Section: 2. Cycle Detection
------------------------------------------------------------
  Cyclic table serialized? false
  Error: ...cycle detected during serialization
  Shared reference (non-cyclic) works:
    {
      left = {
        x = 10
      },
      right = {
        x = 10
      }
    }

------------------------------------------------------------
Section: 3. Safe Deserialization (setfenv sandbox)
------------------------------------------------------------
  Deserialized name:   test
  Deserialized values: 3 items
  Deserialized active: true
  Malicious chunk ran? false
  Blocked: ...deserialization error: [string "return os.execut...
  IO access ran?       false
  Blocked: ...deserialization error: [string "return io.open("...
  Bad syntax loaded?   false
  Rejected: ...loadstring failed: [string "return {{{invalid"]:...

------------------------------------------------------------
Section: 4. JSON Encoding
------------------------------------------------------------
  Primitives:
    nil:     null
    true:    true
    false:   false
    42:      42
    3.14:    3.14
    string:  "hello\tworld"
  Array:     ["lua", "python", "rust"]
  Object:    {"stable": true, "name": "safe-lua", "version": "1.0"}
  Nested:    {"users": [...], "count": 2}
  Function encoded? false
  Rejected: ...unsupported type for JSON encoding: function

------------------------------------------------------------
Section: 5. Round-Trip Validation
------------------------------------------------------------
  Serialized:
    return {
      version = 2,
      project = "safe-lua-groundtruth",
      empty = {},
      settings = {
        lint_warnings = 0,
        coverage_min = 95,
        frozen = true
      },
      features = {
        "guard",
        "validate",
        "log",
        "perf",
        "freeze",
        "concat"
      }
    }
  Round-trip equal? true
  project:      safe-lua-groundtruth
  version:      2
  features:     6 items
  coverage_min: 95
  empty table:  0 keys

============================================================
Patterns demonstrated:
  Lua table serializer     (cycle detection, escaping)
  Pretty-print             (return prefix, indent)
  Safe deserialization      (setfenv sandbox)
  JSON encoding            (type dispatch, escaping)
  Round-trip validation     (serialize + deserialize)
============================================================
Done.
```

## Pattern Reference

| Pattern                  | Projects                  | Key Technique                      |
|--------------------------|---------------------------|------------------------------------|
| Table serializer         | KOReader dump, xmake      | Recursive with `seen` set          |
| String escaping          | KOReader dump, dkjson      | Byte-level escape via `string_byte` |
| Cycle detection          | KOReader dump              | `guard.contract` on `seen[val]`    |
| Pretty-print             | KOReader dump              | Configurable indent depth          |
| setfenv sandbox          | KOReader unserialize       | Empty env blocks all globals       |
| JSON encode              | APISIX core.json, dkjson   | Array vs object type dispatch      |
| Round-trip validation    | xmake serialize            | Deep equality after deserialize    |
