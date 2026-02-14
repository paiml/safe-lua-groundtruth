# Coroutine Patterns

Six advanced coroutine patterns drawn from real-world
Lua projects. Covers iterator generators, producer-consumer
pipelines, budget-limited schedulers, error handling,
status tracking, and semaphore-based resource limiting.

Unlike the [parallel](./parallel.md) example which
demonstrates a basic round-robin scheduler, this example
focuses on the broader ecosystem of coroutine idioms
found in production Lua codebases.

## Patterns and Real-World Origins

| Pattern | Real-World Project | Technique |
|---------|--------------------|-----------|
| Iterator generator | AwesomeWM `awful.util` | `coroutine.wrap` as iterator |
| Producer-consumer | OpenResty pipelines | Shared buffer with signal flag |
| Budget-limited scheduler | lazy.nvim plugin loader | `os.clock` time-boxed ticks |
| Error handling | Lapis web framework | `pcall` wrapping `resume` |
| Status tracking | Lua reference manual | All four coroutine states |
| Semaphore limiting | xmake build system | Counting semaphore with wait queue |

## Key Patterns

- **`coroutine.wrap`**: Returns a plain function that
  resumes automatically on each call, ideal for iterators
- **Signal-based termination**: Producer sets a `done` flag;
  consumer checks flag when buffer is empty
- **Time-budgeted execution**: `os.clock()` delta limits
  how long a scheduler tick runs before yielding control
- **Safe resume**: Wrapping `coroutine.resume` in `pcall`
  distinguishes coroutine errors from system errors
- **Normal state**: Only observable when a coroutine resumes
  another coroutine (outer becomes "normal")
- **Semaphore**: Counting permits with a wait queue that
  parks excess coroutines via `yield`

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.assert_type` on all function arguments |
| CB-601 | `guard.contract` for positive limits, non-empty tasks |
| CB-607 | `validate.Checker` for budget and semaphore config |

## Source

```lua
{{#include ../../../examples/coroutine_patterns.lua}}
```

## Sample Output

```text
Advanced Coroutine Patterns
============================================================
Six patterns from real-world Lua projects.

============================================================
  Pattern 1: Iterator Generator (coroutine.wrap)
============================================================

--- Fibonacci sequence (first 10) ---
  0, 1, 1, 2, 3, 5, 8, 13, 21, 34

--- In-order BST traversal ---
  Tree: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7


============================================================
  Pattern 2: Producer-Consumer Pipeline
============================================================

  step 1 producer: produced: alpha
  step 1 consumer: consumed: alpha
  step 2 producer: produced: beta
  step 2 consumer: consumed: beta
  step 3 producer: produced: gamma
  step 3 consumer: consumed: gamma
  step 4 producer: produced: delta
  step 4 consumer: consumed: delta

  Final results:
    1. [processed: alpha -> ALPHA]
    2. [processed: beta -> BETA]
    3. [processed: gamma -> GAMMA]
    4. [processed: delta -> DELTA]


============================================================
  Pattern 3: Budget-Limited Scheduler (lazy.nvim)
============================================================

  tick 1: completed=0 remaining=4 (0.02 ms)
  tick 2: completed=0 remaining=4 (0.02 ms)
  tick 3: completed=0 remaining=4 (0.02 ms)
  tick 4: completed=4 remaining=0 (0.00 ms)
  All tasks finished in 4 ticks


============================================================
  Pattern 4: Coroutine Error Handling
============================================================

--- Basic resume error capture ---
  resume 1: ok=true val=step 1 ok
  resume 2: ok=false val=simulated failure in coroutine
  resume 3 (dead): ok=false val=cannot resume dead coroutine

--- Safe resume wrapper with pcall ---
  attempt 1: ok, values=safe step 1
  attempt 2: ok, values=safe step 2
  attempt 3: failed, reason=coroutine error: intentional failure
  attempt 4: failed, reason=cannot resume dead coroutine


============================================================
  Pattern 5: Coroutine Status Tracking
============================================================

  State transitions observed:
  Label                               State
  --------------------------------------------------
  outer initial                       suspended
  inner initial                       suspended
  inner before first resume           suspended
  outer (from inner)                  normal
  inner (self)                        running
  inner after yield                   suspended
  inner resumed                       running
  inner after finish                  dead
  outer final                         dead

  All four states observed:
    suspended    yes
    running      yes
    normal       yes
    dead         yes
  Complete: yes


============================================================
  Pattern 6: Semaphore / Resource Limiting (xmake)
============================================================

  Semaphore permits: 2

--- Execution log ---
  [start] job-1 (active=1)
  [done]  job-1
  [start] job-2 (active=1)
  [done]  job-2
  [start] job-3 (active=1)
  [done]  job-3
  [start] job-4 (active=1)
  [done]  job-4
  [start] job-5 (active=1)
  [done]  job-5

--- Results ---
  job-1    [OK]   job-1 completed
  job-2    [OK]   job-2 completed
  job-3    [OK]   job-3 completed
  job-4    [OK]   job-4 completed
  job-5    [OK]   job-5 completed

============================================================
All patterns demonstrated successfully.
```
