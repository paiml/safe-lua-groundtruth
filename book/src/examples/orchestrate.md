# Shell Orchestration

Multi-stage pipeline runner, like a mini CI system. Defines an ordered list of steps, executes each via `shell.exec`, logs progress, halts on first failure, and reports a summary.

## Key Patterns

- **Safe shell execution**: `shell.build_command` and `shell.exec` with argument arrays
- **Pipeline halt-on-failure**: Stops executing remaining steps when one fails
- **Dry-run mode**: Builds and displays commands without executing them
- **Timing**: `os.clock()` measures per-step execution time

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-603 | `shell.exec` wraps `os.execute` safely |
| CB-601 | `guard.assert_type` validates pipeline structure |
| CB-607 | `validate.Checker` colon-syntax for step validation |

## Source

```lua
{{#include ../../../examples/orchestrate.lua}}
```

## Sample Output

```
Shell Pipeline Orchestrator
==================================================

--- Dry Run ---
Pipeline: 4 steps (dry run)
--------------------------------------------------
[1/4] echo-start -> echo 'Pipeline starting...' (skipped)
[2/4] check-lua -> lua5.1 '-e' 'print('"'"'Lua OK'"'"')' (skipped)
[3/4] list-modules -> ls 'lib/safe/' (skipped)
[4/4] echo-done -> echo 'All steps complete.' (skipped)

Summary:
--------------------------------------------------
  echo-start           [SKIP]
  check-lua            [SKIP]
  list-modules         [SKIP]
  echo-done            [SKIP]
--------------------------------------------------
0 passed, 4 skipped

--- Live Run ---
Pipeline: 4 steps
--------------------------------------------------
[1/4] echo-start [OK] (0.12 ms)
[2/4] check-lua [OK] (1.50 ms)
[3/4] list-modules [OK] (0.08 ms)
[4/4] echo-done [OK] (0.06 ms)

Summary:
--------------------------------------------------
  echo-start           [PASS]
  check-lua            [PASS]
  list-modules         [PASS]
  echo-done            [PASS]
--------------------------------------------------
4 passed
```
