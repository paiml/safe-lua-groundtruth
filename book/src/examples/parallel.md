# Coroutine Parallelization

Cooperative coroutine-based task runner. Dispatches multiple tasks as coroutines, round-robins execution, and collects results. Demonstrates Lua 5.1 coroutine patterns with safe-lua validation and logging.

## Key Patterns

- **Coroutine scheduling**: `coroutine.create`, `coroutine.resume`, `coroutine.yield`, `coroutine.status`
- **Input validation**: `validate.Checker` validates task definitions before scheduling
- **Guard contracts**: `guard.contract` enforces non-empty task lists
- **Structured logging**: `log.with_context` tracks scheduler progress

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.assert_type` on tasks table |
| CB-607 | `validate.Checker` colon-syntax accumulation |

## Source

```lua
{{#include ../../../examples/parallel.lua}}
```

## Sample Output

```
Coroutine Job Scheduler
==================================================

Results:
--------------------------------------------------
  build    [OK] build: completed all 3 steps
  test     [OK] test: completed all 5 steps
  lint     [OK] lint: completed all 2 steps
  docs     [OK] docs: completed all 4 steps
--------------------------------------------------
Elapsed: 0.42 ms
Status: all tasks succeeded
```
