# safe.validate

Input validation with error accumulation. Non-throwing checks return `ok, err`. The `Checker` object accumulates errors for batch assertion.

```lua
local validate = require("safe.validate")
```

## Source

```lua
--[[
  validate.lua — Input validation with error accumulation.
  Non-throwing checks return ok, err. Checker accumulates errors.
]]

local M = {}

local type = type
local tostring = tostring
local string_format = string.format
local table_concat = table.concat
local error = error
local pairs = pairs

--- Non-throwing type check.
--- @param value any
--- @param expected string
--- @param name string
--- @return boolean ok, string|nil err
function M.check_type(value, expected, name)
    if type(value) ~= expected then
        return false, string_format("expected %s to be %s, got %s", tostring(name), expected, type(value))
    end
    return true, nil
end

--- Non-throwing nil check.
--- @param value any
--- @param name string
--- @return boolean ok, string|nil err
function M.check_not_nil(value, name)
    if value == nil then
        return false, string_format("expected %s to be non-nil", tostring(name))
    end
    return true, nil
end

--- Non-throwing numeric range check.
--- @param value number
--- @param min number
--- @param max number
--- @param name string
--- @return boolean ok, string|nil err
function M.check_range(value, min, max, name)
    if type(value) ~= "number" then
        return false, string_format("expected %s to be number, got %s", tostring(name), type(value))
    end
    -- NaN fails all comparisons, so check explicitly: NaN ~= NaN
    if value ~= value then
        return false, string_format("%s is NaN", tostring(name))
    end
    if value < min or value > max then
        return false,
            string_format(
                "%s must be between %s and %s, got %s",
                tostring(name),
                tostring(min),
                tostring(max),
                tostring(value)
            )
    end
    return true, nil
end

--- Non-throwing string presence check.
--- @param value any
--- @param name string
--- @return boolean ok, string|nil err
function M.check_string_not_empty(value, name)
    if type(value) ~= "string" then
        return false, string_format("expected %s to be string, got %s", tostring(name), type(value))
    end
    if value == "" then
        return false, string_format("%s must not be empty", tostring(name))
    end
    return true, nil
end

--- Non-throwing enum membership check.
--- @param value any
--- @param allowed table array of allowed values
--- @param name string
--- @return boolean ok, string|nil err
function M.check_one_of(value, allowed, name)
    for i = 1, #allowed do
        if value == allowed[i] then
            return true, nil
        end
    end
    local parts = {}
    for i = 1, #allowed do
        parts[i] = tostring(allowed[i])
    end
    return false,
        string_format("%s must be one of [%s], got %s", tostring(name), table_concat(parts, ", "), tostring(value))
end

--- Error accumulation object. Uses colon syntax (CB-607: stateful object).
local Checker = {}
Checker.__index = Checker

--- Create a new Checker instance.
--- @return table checker
function Checker:new()
    local self = setmetatable({}, Checker)
    self._errors = {}
    return self
end

--- Accumulate a type check.
function Checker:check_type(value, expected, name)
    local ok, err = M.check_type(value, expected, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate a nil check.
function Checker:check_not_nil(value, name)
    local ok, err = M.check_not_nil(value, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate a range check.
function Checker:check_range(value, min, max, name)
    local ok, err = M.check_range(value, min, max, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate a string presence check.
function Checker:check_string_not_empty(value, name)
    local ok, err = M.check_string_not_empty(value, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate an enum membership check.
function Checker:check_one_of(value, allowed, name)
    local ok, err = M.check_one_of(value, allowed, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Check if all validations passed.
function Checker:ok()
    return #self._errors == 0
end

--- Get accumulated error messages.
function Checker:errors()
    local copy = {}
    for i = 1, #self._errors do
        copy[i] = self._errors[i]
    end
    return copy
end

--- Throw if any errors accumulated.
function Checker:assert(level)
    if #self._errors > 0 then
        error(table_concat(self._errors, "; "), (level or 2))
    end
end

M.Checker = Checker

--- Validate a table against a schema definition.
--- Schema is a table of { field_name = { type = "string", required = true, default = value } }.
--- Returns a validated copy with defaults applied.
function M.schema(tbl, schema_def)
    if type(tbl) ~= "table" then
        return false, "expected table, got " .. type(tbl)
    end
    local result = {}
    local errs = {}
    for field, spec in pairs(schema_def) do
        local value = tbl[field]
        if value == nil then
            if spec.default ~= nil then
                result[field] = spec.default
            elseif spec.required then
                errs[#errs + 1] = string_format("missing required field: %s", field)
            end
        else
            if spec.type and type(value) ~= spec.type then
                errs[#errs + 1] = string_format("field %s: expected %s, got %s", field, spec.type, type(value))
            else
                result[field] = value
            end
        end
    end
    -- Copy fields not in schema
    for k, v in pairs(tbl) do
        if schema_def[k] == nil then
            result[k] = v
        end
    end
    if #errs > 0 then
        return false, table_concat(errs, "; ")
    end
    return true, result
end

return M
```

## Functions

### Non-Throwing Checks

All `check_*` functions return `ok, err` — they never throw.

#### `validate.check_type(value, expected, name)`

```lua
local ok, err = validate.check_type(42, "string", "name")
-- ok = false, err = "expected name to be string, got number"
```

#### `validate.check_not_nil(value, name)`

```lua
local ok, err = validate.check_not_nil(nil, "config")
-- ok = false, err = "expected config to be non-nil"
```

#### `validate.check_range(value, min, max, name)`

Validates that a value is a number within `[min, max]`. Explicitly rejects NaN:

```lua
local ok, err = validate.check_range(0/0, 1, 10, "x")
-- ok = false, err = "x is NaN"

local ok, err = validate.check_range(math.huge, 1, 10, "x")
-- ok = false, err = "x must be between 1 and 10, got inf"
```

The NaN check was added after falsification testing revealed that `NaN < min` and `NaN > max` are both false in IEEE 754, causing NaN to pass range checks silently.

#### `validate.check_string_not_empty(value, name)`

```lua
local ok, err = validate.check_string_not_empty("", "username")
-- ok = false, err = "username must not be empty"
```

#### `validate.check_one_of(value, allowed, name)`

```lua
local ok, err = validate.check_one_of("admin", {"user", "guest"}, "role")
-- ok = false, err = "role must be one of [user, guest], got admin"
```

### Error Accumulation: `validate.Checker`

The `Checker` object uses colon syntax (CB-607: stateful object) and supports method chaining:

```lua
local c = validate.Checker:new()
c:check_type(name, "string", "name")
 :check_range(age, 0, 150, "age")
 :check_one_of(role, {"admin", "user"}, "role")

if c:ok() then
    -- all checks passed
else
    local errors = c:errors()  -- returns a copy
end

c:assert()  -- throws with all errors joined by "; "
```

### Schema Validation: `validate.schema(tbl, schema_def)`

Validates a table against a schema definition and returns a validated copy with defaults applied:

```lua
local ok, result = validate.schema(input, {
    name = { type = "string", required = true },
    age  = { type = "number", default = 0 },
    role = { type = "string", default = "user" },
})
```

Schema spec fields:
- `type` — expected Lua type name
- `required` — if `true`, missing field is an error (unless `default` is set)
- `default` — value to use when field is absent

Fields present in `tbl` but not in the schema are copied through to the result.

## Known Limitations

- **`false` as default**: `spec.default ~= nil` means `false` works as a default value, but the check is `~= nil` not truthiness-based.
- **Required + default**: If both `required = true` and `default` are set, the default takes precedence — the required check never fires for absent fields.
- **Schema error order is nondeterministic**: Multiple errors are
  collected via `pairs()` iteration over the schema, so their order
  depends on Lua's hash table implementation.
- **Floating-point boundaries**: `check_range` uses `<` and `>` comparisons, so floating-point edge cases at boundaries depend on IEEE 754 representation.
