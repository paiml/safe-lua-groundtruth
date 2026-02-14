# safe-lua-groundtruth

Gold-standard safe Lua 5.1 library demonstrating defensive patterns.

## Quick Commands

- `make test` — Run all busted specs
- `make lint` — Zero-warning luacheck + selene
- `make fmt` — Format all Lua with stylua
- `make fmt-check` — CI format gate
- `make coverage` — 95% minimum on lib/
- `make check` — Full quality gate (lint + fmt-check + test)
- `make bench` — Run performance benchmarks
- `make reproduce` — Clean + check + coverage

## Module Paths

All production code lives in `lib/safe/`. Require as:
```lua
local guard = require("safe.guard")
local log = require("safe.log")
```

## Conventions

- Dot syntax by default; colon only for stateful objects (validate.Checker)
- Local-cache all stdlib functions at module top
- Every module returns a table `M`
- 95% minimum test coverage enforced
- Zero SATD (no TODO/FIXME/HACK/XXX in lib/ or spec/)
- PMAT CB-600 compliance required on all lib/ modules

## Code Search

NEVER use grep/glob for code search. ALWAYS prefer `pmat query`:

| Task | Command |
|------|---------|
| Find functions by intent | `pmat query "validation" --limit 10` |
| Find code with fault patterns | `pmat query "error handling" --faults --exclude-tests` |
| Find by quality grade | `pmat query "guard" --min-grade A` |
| Regex search | `pmat query --regex "function M%." --limit 20` |
| Literal string search | `pmat query --literal "require" --limit 10` |
| Coverage gaps | `pmat query --coverage-gaps --limit 20` |
| Git history search | `pmat query "fix nil" -G` |
| Volatile hot code | `pmat query "concat" --churn` |
