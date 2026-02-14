# Mutation Testing

A mutation testing harness that takes a pure function, generates arithmetic and boundary mutants, runs a test suite against each mutant, and reports killed/survived/score.

## Key Patterns

- **Mutant generation**: Systematic mutations (operator swap, boundary shift, constant return)
- **Test-driven killing**: Each mutant is run against the full test suite
- **Score reporting**: Mutation score = killed / total, with threshold check
- **Guard contracts**: `guard.contract` validates mutant array structure

## Mutation Types

| Mutation | Description |
|----------|-------------|
| Negate subtraction | `a - b` becomes `a + b` |
| Remove abs | `math.abs(a - b)` becomes `a - b` |
| Off-by-one clamp | `>` becomes `>=` |
| Constant return (0) | Always returns 0 |
| Constant return (max) | Always returns max_val |
| Swap direction | `>` becomes `<` |
| Off-by-one result | Result `+ 1` |

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.contract` validates preconditions |
| CB-602 | `pcall` wraps each mutant test safely |
| CB-607 | `validate.Checker` colon-syntax validation |

## Source

```lua
{{#include ../../../examples/mutate.lua}}
```

## Sample Output

```
Mutation Testing Harness
==================================================

Original function: PASS (all tests green)

Testing 7 mutants...
--------------------------------------------------
  [KILLED]   negate subtraction (a + b)
  [KILLED]   remove abs (a - b raw)
  [KILLED]   off-by-one clamp (>=)
  [KILLED]   return 0 always
  [KILLED]   return max always
  [KILLED]   swap clamp direction (<)
  [KILLED]   off-by-one result (+1)
--------------------------------------------------
Killed:   7/7
Survived: 0/7
Score:    100.0%
Elapsed:  0.03 ms
```
