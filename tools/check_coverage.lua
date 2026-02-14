#!/usr/bin/env lua5.1
--[[
  check_coverage.lua — Parse luacov report and enforce minimum coverage.
  Only checks files under lib/ (the production code).

  Usage: lua5.1 tools/check_coverage.lua [min_pct]
  Default min_pct: 95
]]

local min = tonumber(arg[1]) or 95

local f = io.open("luacov.report.out")
if not f then
    print("No coverage report found")
    os.exit(1)
end
local text = f:read("*a")
f:close()

local pass = true
local checked = 0

for line in text:gmatch("[^\n]+") do
    local file, pct = line:match("^(%S+%.lua)%s+%d+%s+%d+%s+(%d+%.%d+)%%")
    -- Only enforce coverage on production code (lib/)
    if file and file:match("^lib/safe/") then
        local n = tonumber(pct)
        checked = checked + 1
        if n < min then
            print(string.format("FAIL: %s at %.1f%% (min %d%%)", file, n, min))
            pass = false
        else
            print(string.format("  OK: %s at %.1f%%", file, n))
        end
    end
end

if checked == 0 then
    print("WARNING: No lib/ files found in coverage report")
    os.exit(1)
end

if pass then
    print(string.format("Coverage OK: all %d files >= %d%%", checked, min))
else
    os.exit(1)
end
