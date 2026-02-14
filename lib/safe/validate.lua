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
function Checker.new()
    local self = setmetatable({}, Checker)
    self._errors = {}
    return self
end

--- Accumulate a type check.
--- @param value any
--- @param expected string
--- @param name string
--- @return table self
function Checker:check_type(value, expected, name)
    local ok, err = M.check_type(value, expected, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate a nil check.
--- @param value any
--- @param name string
--- @return table self
function Checker:check_not_nil(value, name)
    local ok, err = M.check_not_nil(value, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate a range check.
--- @param value number
--- @param min number
--- @param max number
--- @param name string
--- @return table self
function Checker:check_range(value, min, max, name)
    local ok, err = M.check_range(value, min, max, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate a string presence check.
--- @param value any
--- @param name string
--- @return table self
function Checker:check_string_not_empty(value, name)
    local ok, err = M.check_string_not_empty(value, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Accumulate an enum membership check.
--- @param value any
--- @param allowed table
--- @param name string
--- @return table self
function Checker:check_one_of(value, allowed, name)
    local ok, err = M.check_one_of(value, allowed, name)
    if not ok then
        self._errors[#self._errors + 1] = err
    end
    return self
end

--- Check if all validations passed.
--- @return boolean
function Checker:ok()
    return #self._errors == 0
end

--- Get accumulated error messages.
--- @return table array of error strings
function Checker:errors()
    local copy = {}
    for i = 1, #self._errors do
        copy[i] = self._errors[i]
    end
    return copy
end

--- Throw if any errors accumulated.
--- @param level number|nil stack level (default 2)
function Checker:assert(level)
    if #self._errors > 0 then
        error(table_concat(self._errors, "; "), (level or 2))
    end
end

M.Checker = Checker

--- Validate a table against a schema definition.
--- Schema is a table of { field_name = { type = "string", required = true, default = value } }.
--- Returns a validated copy with defaults applied.
--- @param tbl table input table
--- @param schema_def table schema definition
--- @return boolean ok, table|string result_or_error
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
