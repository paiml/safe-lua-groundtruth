# CLI Tool

A safe command-line tool demonstrating guard contracts, input validation
with error accumulation, and safe shell execution.
Implements a `search` and `count` subcommand pattern with proper argument handling.

## Key Patterns

- **Frozen enum dispatch**: `guard.enum` creates an immutable command registry
- **Error accumulation**: `validate.Checker` collects multiple validation errors before reporting
- **Safe shell capture**: `shell.capture` runs `grep` and `find` with escaped arguments
- **Structured logging**: `log.set_output` redirects logs to stderr, keeping stdout clean for tool output

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-600 | `guard.enum` prevents unknown command injection |
| CB-601 | `guard.safe_get` not needed (flat args), but nil checked via validate |
| CB-603 | `shell.capture` wraps `grep` and `find` safely |
| CB-607 | `validate.Checker` colon-syntax for error accumulation |

## Source

```lua
{{#include ../../../examples/cli_tool.lua}}
```

## Sample Output

```
$ lua5.1 examples/cli_tool.lua --help
Usage: lua5.1 examples/cli_tool.lua <command> [args...]

Commands:
  search <pattern> <dir>   Search files for a pattern
  count <dir>              Count files in a directory
  --help                   Show this message

$ lua5.1 examples/cli_tool.lua search "require" lib/safe/
lib/safe/validate.lua:201:--- Schema is a table of { ... required = true ... }.
lib/safe/validate.lua:217:            elseif spec.required then
lib/safe/validate.lua:218:                errs[#errs + 1] = string_format("missing required field: %s", field)
```
