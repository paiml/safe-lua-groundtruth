# Module Overview

All production code lives in `lib/safe/`. Each module is self-contained and returns a table `M`.

## Shared Conventions

Every module follows these patterns:

### Local Caching

Standard library functions are cached in local variables at module top. This is both a performance optimization (avoids global table lookups) and a safety measure (prevents monkey-patching from affecting module internals).

```lua
local type = type
local error = error
local tostring = tostring
local string_format = string.format
```

### Module Table

Each module creates a local table `M`, attaches all public functions to it, and returns it:

```lua
local M = {}

function M.my_function(...)
    -- ...
end

return M
```

### Dot vs Colon Syntax

Dot syntax is the default (CB-607). Colon syntax is used only for stateful objects where method chaining makes sense:

- **Dot**: `guard.safe_get(t, "key")`, `shell.exec("ls", {"-la"})`
- **Colon**: `checker:check_type(val, "string", "name")` — the `Checker` object accumulates state

### Error Reporting

Two patterns are used:

1. **Throwing**: `guard.assert_type`, `guard.contract` — raise `error()` with configurable stack level
2. **Non-throwing**: `validate.check_type`, `shell.validate_program` — return `ok, err` pairs

## Module Summary

| Module | Purpose | Key Pattern |
|--------|---------|-------------|
| [guard](guard.md) | Defensive primitives | Nil-safe access, type contracts, frozen tables |
| [log](log.md) | Structured logging | Level gating, injectable output, child loggers |
| [validate](validate.md) | Input validation | Non-throwing checks, error accumulation, schema |
| [shell](shell.md) | Safe shell execution | Argument arrays, escaping, swappable executor |
| [perf](perf.md) | Performance patterns | table.concat, numeric for, table reuse |
| [test_helpers](test_helpers.md) | Testing utilities | Mock factories, output capture, temp files |
