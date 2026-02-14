# CB-600 Compliance

The PMAT CB-600 series defines checks for common Lua defect patterns. This library demonstrates compliant solutions for each check.

## Compliance Matrix

| Check | Name | Risk | Demonstrated In |
|-------|------|------|-----------------|
| CB-600 | Implicit globals | Bugs from typos, namespace pollution | `guard.protect_globals` |
| CB-601 | Nil-unsafe access | Nil dereference crashes | `guard.safe_get`, `guard.assert_not_nil` |
| CB-602 | pcall handling | Uncaught errors in protected calls | `test_helpers.capture_output` |
| CB-603 | Dangerous APIs | `os.execute`, `io.popen`, `loadstring` | `shell.exec`, `shell.capture` |
| CB-604 | Unused variables | Dead code, typos | Enforced by luacheck + selene |
| CB-605 | String concat in loops | O(n^2) allocation | `perf.concat_safe` vs `perf.concat_unsafe` |
| CB-606 | Missing module return | Module returns nil instead of table | All modules return `M` |
| CB-607 | Colon/dot confusion | Silent `self` bugs | `validate.Checker` documents colon usage |

## CB-600: Implicit Globals

**Problem**: Lua variables are global by default. A typo like `reuslt = compute()` silently creates a new global instead of raising an error.

**Solution**: `guard.protect_globals(env)` installs a metatable that errors on access to or assignment of any variable not present when the function was called.

```lua
guard.protect_globals(_G)
reuslt = 42  --> error: assignment to undeclared global: reuslt
```

## CB-601: Nil-Unsafe Access

**Problem**: Chained access like `config.database.primary.host` crashes if any intermediate table is nil.

**Solution**: `guard.safe_get` traverses the chain and returns nil at the first miss:

```lua
guard.safe_get(config, "database", "primary", "host")
-- Returns nil instead of crashing if "database" or "primary" is missing
```

## CB-602: pcall Handling

**Problem**: Code that uses `pcall` but ignores the error return value silently swallows failures.

**Solution**: `test_helpers.capture_output` demonstrates correct pcall usage — it captures the error and re-raises it after cleanup:

```lua
local ok, err = pcall(fn)
io.write = orig_write  -- cleanup happens regardless
if not ok then
    error(err, 2)      -- re-raise, don't swallow
end
```

## CB-603: Dangerous APIs

**Problem**: `os.execute` and `io.popen` allow arbitrary shell command execution. Raw string building enables injection.

**Solution**: `shell.exec` and `shell.capture` enforce safety through argument arrays and escaping. The dangerous APIs are used only through validated, escaped command strings. Annotated with `pmat:ignore CB-603` to acknowledge intentional use.

```lua
-- NEVER: os.execute("grep -r " .. user_input .. " /path")
-- ALWAYS:
shell.exec("grep", {"-r", user_input, "/path"})
```

## CB-604: Unused Variables

**Problem**: Unused variables often indicate typos or incomplete refactoring.

**Solution**: Enforced statically by two independent linters:
- **luacheck**: Warns on unused locals and unused loop variables
- **selene**: Additional unused variable detection with different heuristics

Both must report zero warnings for `make lint` to pass.

## CB-605: String Concatenation in Loops

**Problem**: Repeated `result = result .. str` in a loop creates a new string each iteration, leading to O(n^2) total allocation.

**Solution**: `perf.concat_safe` accumulates parts in a table and joins with `table.concat`:

```lua
-- Anti-pattern (O(n^2)):
local result = ""
for i = 1, n do result = result .. parts[i] end

-- Gold standard (O(n)):
local result = table.concat(parts)
```

See [Benchmarks](benchmarks.md) for quantitative comparison.

## CB-606: Missing Module Return

**Problem**: A Lua module file that doesn't return a value causes `require()` to return `true`, which is useless and error-prone.

**Solution**: Every module in this library follows the pattern:

```lua
local M = {}
-- ... attach functions to M ...
return M
```

## CB-607: Colon/Dot Confusion

**Problem**: Calling a method with `.` instead of `:` (or vice versa) causes `self` to be wrong — either missing or shifted.

**Solution**: This library uses dot syntax by default. Colon syntax is reserved for `validate.Checker`, which is explicitly documented as a stateful object:

```lua
-- Dot (default): function is stateless
validate.check_type(val, "string", "name")

-- Colon (Checker only): method accumulates state in self
local c = validate.Checker.new()
c:check_type(val, "string", "name")
```
