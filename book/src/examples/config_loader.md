# Config Loading

Demonstrates config loading and schema validation patterns used in resolve-pipeline.
Shows `dofile`-based config loading, `validate.schema()` for structural validation,
defaults via `or`, nested config sections, and freezing validated configs
to prevent accidental modification.

## Key Patterns

- **Schema validation**: `validate.schema()` checks types, required fields, and applies defaults
- **Nested config**: Branding and video subsections each validated against their own schema
- **Defaults via `or`**: `(table and table.key) or default` pattern for safe property access
- **Frozen config**: `guard.freeze()` makes validated config immutable
- **Error accumulation**: Schema returns all errors, not just the first

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-600 | Frozen config prevents accidental global mutation |
| CB-601 | `validate.schema()` nil-safe field access with defaults |
| CB-606 | Config loaded as table return value |
| CB-607 | `validate.Checker` colon-syntax for video validation |

## Source

```lua
{{#include ../../../examples/config_loader.lua}}
```

## Sample Output

```
Config Loading & Schema Validation
==================================================

1. Valid Config (with defaults)
--------------------------------------------------
  project_name: AdvancedFineTuning_Rust_Coursera
  frame_rate:   30
  output_dir:   ./output
  log_level:    INFO
  title_font:   Roboto
  videos:       2 entries
    [1] 1.1.1-core-concepts — Core Concepts
    [2] 1.1.2-architecture — Untitled
  fade_frames:  15
  frozen:       immutable (good)

2. Missing Required Fields
--------------------------------------------------
  ok:    false
  error: project config: missing required field: project_name

3. Wrong Field Types
--------------------------------------------------
  ok:    false
  error: project config: field frame_rate: expected number, got string; ...

4. Invalid Video Entry
--------------------------------------------------
  ok:    false
  error: video[2]: missing required field: id

5. Nil Config
--------------------------------------------------
  ok:    false
  error: config must be a table, got nil
```
