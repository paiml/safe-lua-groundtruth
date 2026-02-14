# String Processing

String pattern matching and transformation patterns from resolve-pipeline. Demonstrates `gmatch` line iteration, `gsub` with callbacks for SRT timestamp offsetting, Lua pattern escaping, frontier patterns for word boundaries, Levenshtein distance, and safe string building.

## Key Patterns

- **Line iteration**: `text:gmatch("[^\n]+")` iterates lines without splitting into a table
- **gsub with callback**: `content:gsub(pattern, function(match) ... end)` for in-place transforms
- **Pattern escaping**: `escape_pattern()` makes literal strings safe for Lua pattern matching
- **Frontier patterns**: `%f[%w]` and `%f[%W]` match word boundaries without consuming characters
- **Levenshtein distance**: O(min(m,n)) space edit distance for typo detection
- **Vocabulary matching**: Find closest known word from a vocabulary list

## Patterns from resolve-pipeline

| resolve-pipeline | This example |
|-----------------|--------------|
| `transcribe.lua` SRT offset | `offset_srt_timestamps()` with gsub callback |
| `transcribe.lua` regex escaping | `escape_pattern()` |
| `transcribe.lua` word boundary | `replace_word()` with frontier `%f[]` |
| `vocab_oracle.lua` Levenshtein | `levenshtein()` with rolling arrays |
| `vocab_oracle.lua` closest match | `closest_match()` |
| `perf.concat_safe` | Safe string building demo |

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.assert_type` validates string inputs |
| CB-605 | `perf.concat_safe` for string building instead of loop concat |
| CB-607 | `validate.Checker` colon-syntax for `replace_word` validation |

## Source

```lua
{{#include ../../../examples/string_processing.lua}}
```

## Sample Output

```
String Processing Patterns
==================================================

1. Line Iteration (gmatch)
--------------------------------------------------
  Title: Introduction to Lua
  Author: Noah
  Version: 1.0
  Format: markdown

2. gsub Callback (SRT Offset)
--------------------------------------------------
  Before (offset +0s):
    1
    00:00:05,000 --> 00:00:10,500
    Hello world
    2
    00:00:11,000 --> 00:00:15,200
    Second line
  After (offset +30.5s):
    1
    00:00:35,500 --> 00:00:41,000
    Hello world
    2
    00:00:41,500 --> 00:00:45,700
    Second line

3. Pattern Escaping
--------------------------------------------------
  hello.world     -> hello%.world
  fn(x)           -> fn%(x%)
  100%            -> 100%%
  a+b=c           -> a%+b=c
  [test]          -> %[test%]

4. Frontier Patterns (word boundary)
--------------------------------------------------
  input:  The cat concatenated the catalog categories
  output: The dog concatenated the catalog categories
  replacements: 1 (only whole word 'cat')

5. Levenshtein Distance
--------------------------------------------------
  d(kitten, sitting) = 3
  d(Lua, Lua) = 0
  d(Saturday, Sunday) = 3
  d(LoRA, Laura) = 2

6. Vocabulary Matching
--------------------------------------------------
  functon -> function (distance 1)
  corroutine -> coroutine (distance 1)
  metatble -> metatable (distance 1)
  reqire -> require (distance 2)

7. Safe String Building
--------------------------------------------------
  parts:  5
  result: segment_1segment_2segment_3segment_4segment_5
```
