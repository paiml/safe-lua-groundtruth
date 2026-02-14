# Quality Gates

All quality gates must pass before code is merged. Run `make check` for the full suite.

## Linting

Two independent linters enforce zero warnings:

### luacheck

Static analysis for Lua. Catches unused variables, global access, redefined locals, and style issues.

```bash
luacheck lib/ spec/ tools/
```

Configuration: `.luacheckrc` (project root).

### selene

Additional static analysis with different heuristics. Runs on production code and test code separately (different standard library configs).

```bash
selene lib/
cd spec && selene .
```

Configuration:
- `selene.toml` — production code config
- `spec/selene.toml` — test code config (uses `lua51+busted` standard)
- `spec/busted.yml` — busted standard library definitions for selene

Key annotation patterns:
- `-- selene: allow(global_usage)` — for intentional `_G` access
- `-- selene: allow(incorrect_standard_library_use)` — for `io.write` monkey-patching in test helpers

## Formatting

All Lua files are formatted with **stylua**:

- Line width: 120 columns
- Indent: 4 spaces
- Quote style: double quotes

```bash
stylua --check lib/ spec/ tools/ benchmarks/  # CI gate
stylua lib/ spec/ tools/ benchmarks/           # auto-format
```

## Testing

Tests use the **busted** framework:

```bash
busted spec/
```

The test suite includes:
- Unit tests for each module (`spec/*_spec.lua`)
- Falsification tests (`spec/falsify_spec.lua`) — adversarial edge cases

251 total tests across 7 spec files.

## Coverage

95% minimum coverage enforced on all files under `lib/safe/`:

```bash
busted --coverage spec/
luacov
lua5.1 tools/check_coverage.lua 95
```

The `tools/check_coverage.lua` script parses the luacov report and enforces the minimum percentage per file. Any file below threshold fails the build.

Coverage tool: **luacov** (not tarpaulin — Lua-native coverage).

## SATD (Self-Admitted Technical Debt)

Zero tolerance for SATD markers in production and test code:

- No `TODO` in `lib/` or `spec/`
- No `FIXME` in `lib/` or `spec/`
- No `HACK` in `lib/` or `spec/`
- No `XXX` in `lib/` or `spec/`

`pmat:ignore` annotations are allowed — these are intentional acknowledgments of known patterns, not technical debt.

## CI Pipeline

The full quality gate runs as:

```bash
make check  # = make lint + make fmt-check + make test
```

For a complete reproducibility check including coverage:

```bash
make reproduce  # = make clean + make check + make coverage
```
