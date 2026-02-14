--[[
  perf.lua — Performance patterns demonstrating Lua 5.1 best practices.
  Local caching, table.concat, pre-allocation, numeric for.
]]

local M = {}

local table_concat = table.concat
local string_rep = string.rep
local string_format = string.format

--- Gold-standard string building: accumulate in table, join with table.concat.
--- @param parts table array of strings
--- @return string
function M.concat_safe(parts)
    return table_concat(parts)
end

--- ANTI-PATTERN: string concatenation in a loop.
--- Intentionally triggers CB-605. Included only for benchmarking comparison.
--- DO NOT use this pattern in production code.
--- @param parts table array of strings
--- @return string
function M.concat_unsafe(parts) -- pmat:ignore CB-605
    local result = ""
    for i = 1, #parts do
        result = result .. parts[i] -- pmat:ignore CB-605
    end
    return result
end

--- Build a repeated string using string.rep (no loop concat).
--- @param n number repetitions
--- @param char string character or substring to repeat
--- @return string
function M.build_string(n, char)
    return string_rep(char, n)
end

--- Sum array elements using numeric for (fastest iteration).
--- @param tbl table array of numbers
--- @return number sum
function M.numeric_for_sum(tbl)
    local sum = 0
    for i = 1, #tbl do
        sum = sum + tbl[i]
    end
    return sum
end

--- Sum array elements using ipairs (comparison).
--- @param tbl table array of numbers
--- @return number sum
function M.ipairs_sum(tbl)
    local sum = 0
    for _, v in ipairs(tbl) do
        sum = sum + v
    end
    return sum
end

--- Clear and refill a table for GC-friendly reuse.
--- @param tbl table table to reuse
--- @param n number number of elements to fill
--- @return table the same table, filled with 1..n
function M.reuse_table(tbl, n)
    -- Clear existing entries
    for i = #tbl, 1, -1 do
        tbl[i] = nil
    end
    -- Refill
    for i = 1, n do
        tbl[i] = i
    end
    return tbl
end

--- Format many items using cached string.format.
--- @param template string format template
--- @param items table array of values
--- @return table array of formatted strings
function M.format_many(template, items)
    local results = {}
    for i = 1, #items do
        results[i] = string_format(template, items[i])
    end
    return results
end

return M
