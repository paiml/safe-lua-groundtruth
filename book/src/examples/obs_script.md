# OBS Studio Scripting

Reference template showing how to integrate safe-lua into an OBS Studio Lua script.
Wraps the OBS API with guard contracts, validates scene/source names,
and uses structured logging.
Includes a stub OBS API so the example runs standalone.

## Key Patterns

- **API wrapping**: OBS functions wrapped with `guard.assert_type` and `guard.assert_not_nil` contracts
- **Input validation**: Scene and source names validated with `validate.check_string_not_empty`
- **Error handling**: Safe wrappers return `nil, error` instead of crashing
- **Structured logging**: `log.with_context("obs")` for all messages

## OBS Integration Points

| OBS Function | safe-lua Pattern |
|-------------|-----------------|
| `obs_get_source_by_name` | `guard.assert_type` on name parameter |
| `obs_source_get_name` | `guard.assert_not_nil` on source handle |
| `obs_enum_scenes` | Iterate with validated access |
| Scene item access | `guard.assert_not_nil` on scene items |

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-600 | No implicit globals in script |
| CB-601 | `guard.assert_not_nil` on all OBS handles |
| CB-602 | `pcall` around nil-contract test |
| CB-607 | Dot syntax for stateless OBS wrappers |

## Source

```lua
{{#include ../../../examples/obs_script.lua}}
```

## Sample Output

```
OBS Studio Script Template
==================================================

Source Audit:
--------------------------------------------------
  Webcam               v4l2_input                     ACTIVE
  Desktop Audio        pulse_output_capture           ACTIVE
  Text Overlay         text_ft2_source_v2             inactive

Scene Layout:
--------------------------------------------------
  Scene: Main Scene
    - Webcam
    - Desktop Audio
  Scene: Intermission
    - Text Overlay

Validation Edge Cases:
--------------------------------------------------
  Get missing source: source not found: NonExistent
  Get empty name:     source_name must not be empty
  Bad scene name:     scene not found: No Such Scene
  Nil source guard:   caught
```
