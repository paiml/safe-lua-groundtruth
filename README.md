<p align="center"><img src="assets/hero.svg" alt="safe-lua-groundtruth" width="800"></p>

# safe-lua-groundtruth

Gold-standard safe Lua 5.1 library demonstrating defensive programming patterns.
Designed as a reference implementation verified by PMAT CB-600 compliance checks.

## PMAT Project Score

| Metric | Value |
|--------|-------|
| Modules | 6 |
| Tests | 251 (195 unit + 56 adversarial) |
| Coverage | 95%+ on all `lib/` modules |
| CB-600 Compliance | 8/8 checks (CB-600 through CB-607) |
| Lint Warnings | 0 (luacheck + selene) |
| SATD | 0 (no TODO/FIXME/HACK/XXX) |
| Bugs Found via Falsification | 5 fixed |

## Documentation

The full reference book is available at
[https://paiml.github.io/safe-lua-groundtruth](https://paiml.github.io/safe-lua-groundtruth)
(deployed via GitHub Pages on tag push).

Build locally:

```bash
make book          # build to book/output/
make book-serve    # serve locally with hot reload
```

## Installation

Requires Lua 5.1 and LuaRocks:

```bash
# Clone the repository
git clone https://github.com/paiml/safe-lua-groundtruth.git
cd safe-lua-groundtruth

# Install dependencies
luarocks install busted
luarocks install luacheck
luarocks install luacov

# Verify installation
make check
```

## Usage

Add `lib/` to your package path and require modules individually:

```lua
package.path = "lib/?.lua;" .. package.path

local guard    = require("safe.guard")
local log      = require("safe.log")
local validate = require("safe.validate")
```

Run quality gates:

```bash
make check      # lint + format check + tests
make coverage   # 95% minimum coverage on lib/
make bench      # performance benchmarks
make examples   # run all example programs
```

## Modules

Each module is required individually:

```lua
local guard    = require("safe.guard")
local log      = require("safe.log")
local validate = require("safe.validate")
local shell    = require("safe.shell")
local perf     = require("safe.perf")
local helpers  = require("safe.test_helpers")
```

### `safe.guard` — Defensive Programming

Nil-safe access, type contracts, frozen tables, global protection.

```lua
-- Nil-safe chained access (never throws)
local name = guard.safe_get(config, "database", "primary", "host")

-- Type contracts
guard.assert_type(port, "number", "port")
guard.assert_not_nil(config, "config")

-- Frozen tables (read-only)
local COLORS = guard.enum({ "RED", "GREEN", "BLUE" })

-- Global protection (errors on undeclared globals)
guard.protect_globals(_G)
```

### `safe.log` — Structured Logging

Level-gated logging with injectable output and timestamps.

```lua
log.set_level(log.DEBUG)
log.set_context("myapp")
log.info("Started server on port %d", 8080)

-- Child loggers with preset context
local db_log = log.with_context("database")
db_log.warn("Connection pool exhausted")
```

### `safe.validate` — Input Validation

Non-throwing checks with error accumulation.

```lua
-- Individual checks return ok, err
local ok, err = validate.check_range(port, 1, 65535, "port")

-- Accumulate multiple checks
local c = validate.Checker:new()
c:check_type(name, "string", "name")
 :check_range(age, 0, 150, "age")
 :check_one_of(role, {"admin", "user"}, "role")
c:assert()  -- throws with all errors joined

-- Schema validation
local ok, result = validate.schema(input, {
    name = { type = "string", required = true },
    age  = { type = "number", default = 0 },
})
```

### `safe.shell` — Safe Shell Execution

Argument-array based command building with proper escaping.

```lua
-- Never build commands from raw strings
local ok, code = shell.exec("grep", { "-r", "pattern", "/path" })
local ok, output = shell.capture("date", { "+%Y-%m-%d" })

-- Escaping
shell.escape("it's")  --> 'it'\''s'
```

### `safe.perf` — Performance Patterns

Demonstrates Lua 5.1 performance best practices.

```lua
-- Gold standard: table.concat
local result = perf.concat_safe({ "a", "b", "c" })

-- GC-friendly table reuse
perf.reuse_table(buffer, 1000)

-- Cached string.format over lists
local labels = perf.format_many("item_%d", { 1, 2, 3 })
```

### `safe.test_helpers` — Testing Utilities

Mock factories, temp files, and assertion helpers.

```lua
-- Mock shell executor
local exec, calls = helpers.mock_executor({{ true, 0 }})
shell._executor = exec

-- Capture io.write output
local output = helpers.capture_output(function()
    io.write("hello")
end)

-- Temp file with automatic cleanup
helpers.with_temp_file("content", function(path)
    -- use path, file is cleaned up after
end)
```

## CB-600 Compliance Matrix

| Check | Description | Demonstrated In |
|-------|-------------|-----------------|
| CB-600 | Implicit globals | `guard.protect_globals` |
| CB-601 | Nil-unsafe access | `guard.safe_get`, `guard.assert_not_nil` |
| CB-602 | pcall handling | `test_helpers.capture_output` |
| CB-603 | Dangerous APIs | `shell.exec`, `shell.capture` (with annotations) |
| CB-604 | Unused variables | All modules (enforced by luacheck + selene) |
| CB-605 | String concat in loops | `perf.concat_safe` vs `perf.concat_unsafe` |
| CB-606 | Missing module return | All modules return `M` |
| CB-607 | Colon/dot confusion | `validate.Checker` (documented colon usage) |

## Quality Gates

- **Linting**: luacheck (zero warnings) + selene (all rules deny)
- **Formatting**: stylua (120 cols, 4-space indent, double quotes)
- **Testing**: busted test framework
- **Coverage**: 95% minimum on `lib/` via luacov
- **SATD**: Zero TODO/FIXME/HACK/XXX in lib/ and spec/

## Contributing

1. Fork the repository
2. Run `make check` to verify the baseline passes
3. Make changes in `lib/safe/` with corresponding tests in `spec/`
4. Ensure `make check` and `make coverage` pass (95% minimum)
5. Submit a pull request

All contributions must pass: zero luacheck warnings, zero selene warnings,
stylua formatting, and 95% test coverage on `lib/`.

## License

MIT
