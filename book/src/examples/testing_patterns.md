# Testing Patterns

Demonstrates mock factories, spy functions, dependency injection, and output capture — all patterns used extensively in resolve-pipeline's test suite. Shows how to test code that depends on shell execution, external APIs, and I/O without actually running those operations.

## Key Patterns

- **Spy functions**: Closure that records all calls and returns a preset value
- **Mock objects**: Table with colon-syntax methods matching a real API (resolve-pipeline's `MockGalleryStill`)
- **Mock executor**: `test_helpers.mock_executor` returns pre-configured success/failure sequences
- **Mock popen**: `test_helpers.mock_popen` returns pre-configured output strings
- **Dependency injection**: Service accepts `deps` table with injectable `executor` and `logger`
- **Output capture**: `test_helpers.capture_output` redirects `io.write` during a function call

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.assert_type` on mock method parameters |
| CB-603 | `shell._executor` and `shell._popen` swapped with mocks — no real shell calls |
| CB-607 | Mock objects use colon syntax matching real API |

## Source

```lua
{{#include ../../../examples/testing_patterns.lua}}
```

## Sample Output

```
Testing Patterns
==================================================

1. Spy Functions
--------------------------------------------------
  calls made:    3
  call 1 args:   hello, world
  call 2 args:   foo
  call 3 args:   (none)

2. Mock Objects (colon syntax)
--------------------------------------------------
  label:    Webcam HD
  active:   true
  label:    Front Camera (after SetLabel)
  active:   false (after SetActive)
  SetLabel(123): rejected (good)

3. Mock Executor (test_helpers)
--------------------------------------------------
  exec 1: true (expected true)
  exec 2: true (expected true)
  exec 3: false (expected false)
  commands captured: 3
    [1] echo 'hello'
    [2] make 'test'
    [3] failing-cmd

4. Mock Popen (test_helpers)
--------------------------------------------------
  capture 1 ok:     true
  capture 1 output: file1.lua
file2.lua
  capture 2 ok:     false
  capture 2 output: nil

5. Dependency Injection
--------------------------------------------------
  commands run:  3
  executor calls: 3
  log messages:  5
    [OK] check
    [OK] build
    [OK] test

6. Output Capture (test_helpers)
--------------------------------------------------
  captured 30 bytes
  content: "captured line 1\ncaptured line 2\n"
```
