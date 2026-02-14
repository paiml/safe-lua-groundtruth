#!/usr/bin/env lua5.1
--[[
  string_processing.lua — Example: string pattern matching and transforms.
  Demonstrates gmatch line iteration, gsub with callbacks, frontier
  patterns, regex escaping, and safe string building.
  Patterns from resolve-pipeline: SRT parsing, vocab correction,
  word boundary matching, Levenshtein distance.

  Usage: lua5.1 examples/string_processing.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")
local perf = require("safe.perf")

local string_format = string.format
local string_rep = string.rep
local string_gsub = string.gsub
local tostring = tostring
local math_min = math.min

log.set_level(log.INFO)
log.set_context("strings")

-- ----------------------------------------------------------------
-- Pattern 1: Line iteration with gmatch
-- ----------------------------------------------------------------

--- Parse key-value metadata from a text block.
--- @param text string multi-line text
--- @return table metadata key-value pairs
local function parse_metadata(text)
    guard.assert_type(text, "string", "text")
    local meta = {}
    for line in text:gmatch("[^\n]+") do
        local key, value = line:match("^(%w+):%s*(.+)$")
        if key and value then
            meta[key] = value
        end
    end
    return meta
end

-- ----------------------------------------------------------------
-- Pattern 2: gsub with callbacks (resolve-pipeline SRT offset)
-- ----------------------------------------------------------------

--- Parse a timestamp string "HH:MM:SS,mmm" to seconds.
--- @param ts string timestamp
--- @return number seconds
local function parse_timestamp(ts)
    local h, m, s, ms = ts:match("(%d+):(%d+):(%d+),(%d+)")
    if not h then
        return 0
    end
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 1000
end

--- Format seconds back to "HH:MM:SS,mmm".
--- @param secs number
--- @return string timestamp
local function format_timestamp(secs)
    if secs < 0 then
        secs = 0
    end
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = math.floor(secs % 60)
    local ms = math.floor((secs * 1000) % 1000 + 0.5)
    return string_format("%02d:%02d:%02d,%03d", h, m, s, ms)
end

--- Offset all SRT timestamps by a delta using gsub callback.
--- @param content string SRT file content
--- @param offset_secs number seconds to add
--- @return string modified content
local function offset_srt_timestamps(content, offset_secs)
    guard.assert_type(content, "string", "content")
    guard.assert_type(offset_secs, "number", "offset_secs")
    return content:gsub("(%d+:%d+:%d+,%d+)", function(ts)
        local t = parse_timestamp(ts)
        return format_timestamp(t + offset_secs)
    end)
end

-- ----------------------------------------------------------------
-- Pattern 3: Regex escaping for safe pattern matching
-- ----------------------------------------------------------------

--- Escape a literal string for use in Lua pattern matching.
--- @param s string literal to escape
--- @return string escaped pattern
local function escape_pattern(s)
    guard.assert_type(s, "string", "s")
    return (string_gsub(s, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- ----------------------------------------------------------------
-- Pattern 4: Frontier patterns for word boundaries
-- ----------------------------------------------------------------

--- Replace whole words only using frontier pattern %f[].
--- @param text string input text
--- @param old_word string word to find
--- @param new_word string replacement
--- @return string modified text, number count
local function replace_word(text, old_word, new_word)
    local c = validate.Checker:new()
    c:check_string_not_empty(text, "text")
    c:check_string_not_empty(old_word, "old_word")
    c:check_string_not_empty(new_word, "new_word")
    c:assert()

    local pattern = "%f[%w]" .. escape_pattern(old_word) .. "%f[%W]"
    return text:gsub(pattern, new_word)
end

-- ----------------------------------------------------------------
-- Pattern 5: Levenshtein distance (resolve-pipeline vocab_oracle)
-- ----------------------------------------------------------------

--- Compute edit distance between two strings.
--- @param a string
--- @param b string
--- @return number distance
local function levenshtein(a, b)
    if not a or not b then
        return 0
    end
    a = a:lower()
    b = b:lower()
    if a == b then
        return 0
    end
    local la, lb = #a, #b
    if la == 0 then
        return lb
    end
    if lb == 0 then
        return la
    end

    -- Keep shorter string as column to minimize space
    if la > lb then
        a, b = b, a
        la, lb = lb, la
    end

    local prev = {}
    local curr = {}
    for j = 0, la do
        prev[j] = j
    end
    for i = 1, lb do
        curr[0] = i
        for j = 1, la do
            local cost = (b:byte(i) == a:byte(j)) and 0 or 1
            curr[j] = math_min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
        end
        prev, curr = curr, prev
    end
    return prev[la]
end

--- Find closest match from a vocabulary list.
--- @param word string input word
--- @param vocab table array of known words
--- @return string|nil best_match
--- @return number distance
local function closest_match(word, vocab)
    guard.assert_type(word, "string", "word")
    guard.assert_type(vocab, "table", "vocab")

    local best_word = nil
    local best_dist = math.huge
    for i = 1, #vocab do
        local dist = levenshtein(word, vocab[i])
        if dist < best_dist then
            best_dist = dist
            best_word = vocab[i]
        end
    end
    return best_word, best_dist
end

local function main(_args)
    io.write("String Processing Patterns\n")
    io.write(string_rep("=", 50) .. "\n\n")

    -- 1. Line iteration with gmatch
    io.write("1. Line Iteration (gmatch)\n")
    io.write(string_rep("-", 50) .. "\n")
    local header = "Title: Introduction to Lua\nAuthor: Noah\nVersion: 1.0\nFormat: markdown"
    local meta = parse_metadata(header)
    for _, key in ipairs({ "Title", "Author", "Version", "Format" }) do
        io.write(string_format("  %s: %s\n", key, tostring(meta[key])))
    end

    -- 2. gsub with callback (SRT timestamp offset)
    io.write("\n2. gsub Callback (SRT Offset)\n")
    io.write(string_rep("-", 50) .. "\n")
    local srt = "1\n00:00:05,000 --> 00:00:10,500\nHello world\n\n2\n00:00:11,000 --> 00:00:15,200\nSecond line\n"
    io.write("  Before (offset +0s):\n")
    for line in srt:gmatch("[^\n]+") do
        io.write(string_format("    %s\n", line))
    end

    local shifted = offset_srt_timestamps(srt, 30.5)
    io.write("  After (offset +30.5s):\n")
    for line in shifted:gmatch("[^\n]+") do
        io.write(string_format("    %s\n", line))
    end

    -- 3. Regex escaping
    io.write("\n3. Pattern Escaping\n")
    io.write(string_rep("-", 50) .. "\n")
    local literals = { "hello.world", "fn(x)", "100%", "a+b=c", "[test]" }
    for i = 1, #literals do
        local escaped = escape_pattern(literals[i])
        io.write(string_format("  %-15s -> %s\n", literals[i], escaped))
    end

    -- 4. Frontier patterns (word boundary)
    io.write("\n4. Frontier Patterns (word boundary)\n")
    io.write(string_rep("-", 50) .. "\n")
    local text = "The cat concatenated the catalog categories"
    io.write("  input:  " .. text .. "\n")
    local replaced, count = replace_word(text, "cat", "dog")
    io.write("  output: " .. replaced .. "\n")
    io.write(string_format("  replacements: %d (only whole word 'cat')\n", count))

    -- Also show that "concatenated" is NOT affected
    guard.contract(replaced:find("concatenated") ~= nil, "concatenated must survive")
    guard.contract(replaced:find("catalog") ~= nil, "catalog must survive")

    -- 5. Levenshtein distance
    io.write("\n5. Levenshtein Distance\n")
    io.write(string_rep("-", 50) .. "\n")
    local pairs_to_test = {
        { "kitten", "sitting" },
        { "Lua", "Lua" },
        { "Saturday", "Sunday" },
        { "LoRA", "Laura" },
    }
    for i = 1, #pairs_to_test do
        local a, b = pairs_to_test[i][1], pairs_to_test[i][2]
        local dist = levenshtein(a, b)
        io.write(string_format("  d(%s, %s) = %d\n", a, b, dist))
    end

    -- 6. Closest vocabulary match
    io.write("\n6. Vocabulary Matching\n")
    io.write(string_rep("-", 50) .. "\n")
    local vocab = { "function", "coroutine", "metatable", "require", "module", "pcall", "string" }
    local typos = { "functon", "corroutine", "metatble", "reqire" }
    for i = 1, #typos do
        local match, dist = closest_match(typos[i], vocab)
        io.write(string_format("  %s -> %s (distance %d)\n", typos[i], tostring(match), dist))
    end

    -- 7. Safe string building with table.concat
    io.write("\n7. Safe String Building\n")
    io.write(string_rep("-", 50) .. "\n")
    local parts = {}
    for i = 1, 5 do
        parts[i] = string_format("segment_%d", i)
    end
    local built = perf.concat_safe(parts)
    io.write("  parts:  " .. #parts .. "\n")
    io.write("  result: " .. built .. "\n")

    io.write("\n")
    log.info("string processing demo complete")
    return 0
end

os.exit(main(arg))
