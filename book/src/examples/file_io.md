# File I/O

Safe file I/O patterns used in resolve-pipeline. Demonstrates reading, writing, existence checks, file size via `seek("end")`, RAII-like cleanup with `with_file`, and `test_helpers.with_temp_file`.

## Key Patterns

- **`read_file`**: Opens, reads `"*a"`, closes. Returns `nil, error` on failure
- **`write_file`**: Validates inputs with `Checker`, opens, writes, closes. Returns `false, error` on failure
- **`file_exists`**: Opens in read mode, closes immediately. No error throwing
- **`file_size`**: Uses `seek("end")` to get byte count without reading content
- **`with_file`**: RAII cleanup pattern — `pcall` wraps callback, file handle always closed
- **`with_temp_file`**: `test_helpers` pattern — creates temp, calls function, auto-removes

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | Nil checks on all `io.open` return values |
| CB-602 | `pcall` in `with_file` catches callback errors, still closes handle |
| CB-607 | `validate.Checker` colon-syntax for write validation |

## Source

```lua
{{#include ../../../examples/file_io.lua}}
```

## Sample Output

```
Safe File I/O Patterns
==================================================

1. Write & Read
--------------------------------------------------
  write ok: true
  read ok:  true
  lines:    3

2. Existence Checks
--------------------------------------------------
  temp file exists: true
  missing exists:   false
  nil exists:       false

3. File Size (seek pattern)
--------------------------------------------------
  size: 21 bytes

4. with_file (RAII Cleanup)
--------------------------------------------------
  read via with_file: true
  error caught:       true
  cleanup ran:        true (file handle closed)

5. test_helpers.with_temp_file
--------------------------------------------------
  temp path: /tmp/lua_XXXXXX
  exists:    true
  content:   hello from temp
  (temp file auto-cleaned)

6. Error Handling
--------------------------------------------------
  read empty path:  path must not be empty
  read missing:     cannot open file: /nonexistent/file.txt
  write empty path: path must not be empty
```
