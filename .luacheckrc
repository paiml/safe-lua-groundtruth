-- luacheck configuration for safe-lua-groundtruth
std = "lua51"

files["spec/**"] = {
    std = "lua51+busted",
}

-- test_helpers needs to monkey-patch io.write for capture_output
files["lib/safe/test_helpers.lua"] = {
    globals = { "io" },
}

-- Ignore unused self from colon-syntax method definitions
-- Ignore unused variables with _ prefix (convention for intentionally unused)
ignore = {
    "212/self",  -- unused argument 'self'
    "212/_.*",   -- unused argument with _ prefix
    "211/_.*",   -- unused variable with _ prefix
    "231/_.*",   -- variable with _ prefix set but never accessed
    "241/_.*",   -- variable with _ prefix mutated but never accessed
}

-- Max line length
max_line_length = 120
