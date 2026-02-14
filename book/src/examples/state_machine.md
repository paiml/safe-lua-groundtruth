# State Machine

Phase/state machine pipeline with timing, directly modeled on resolve-pipeline's
`phase_start`/`phase_pass`/`phase_fail` lifecycle.
Demonstrates state accumulation, elapsed time measurement,
halt-on-failure, and completeness checking.

## Key Patterns

- **Phase lifecycle**: `phase_start(state, name)` → `phase_pass(state)` or `phase_fail(state, reason)`
- **State object**: `create_state(n)` returns table with results, timings, output arrays
- **Timing**: `os.clock()` delta for per-phase elapsed time
- **Halt-on-failure**: Pipeline stops executing remaining phases when one fails
- **Completeness property**: Checks `current_phase == total_phases` to detect incomplete runs

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.assert_not_nil` on state in every phase function |
| CB-607 | `validate.Checker` colon-syntax for config validation phase |

## Source

```lua
{{#include ../../../examples/state_machine.lua}}
```

## Sample Output

```
Phase/State Machine Pipeline
============================================================

--- Pipeline 1: Success Path ---

Phase Results:
------------------------------------------------------------
  Phase  1: Validate Configuration         PASS  (0.01 ms)
  Phase  2: Check Assets                   PASS  (0.00 ms)
  Phase  3: Compute Timeline               PASS  (0.15 ms)
------------------------------------------------------------
  3 passed, 0 failed, 3 total (0.16 ms)

--- Pipeline 2: Failure Path ---

Phase Results:
------------------------------------------------------------
  Phase  1: Validate Configuration         PASS  (0.00 ms)
  Phase  2: Check Assets                   PASS  (0.00 ms)
  Phase  3: Render Passes                  FAIL  (0.00 ms)
           simulated: render engine unavailable
------------------------------------------------------------
  2 passed, 1 failed, 3 total (0.01 ms)
  WARNING: ran 3/4 phases (incomplete)
```
