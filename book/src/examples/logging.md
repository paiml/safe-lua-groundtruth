# Structured Logging

Demonstrates `safe.log` features: level gating, child loggers with context tags,
custom output handlers (JSON format),
and custom timestamp functions (monotonic elapsed time).

## Key Patterns

- **Level gating**: `log.set_level` controls which messages are emitted
- **Child loggers**: `log.with_context` creates loggers with preset context tags (database, http, cache)
- **Output injection**: `log.set_output` redirects and reformats log messages (JSON example)
- **Custom timestamps**: `log.set_timestamp` switches from wall clock to monotonic elapsed time

## CB Checks Demonstrated

| Check | Where |
|-------|-------|
| CB-601 | `guard.contract` validates computed sum is positive |
| CB-607 | Dot syntax throughout — `log` is stateless at the call site |

## Source

```lua
{{#include ../../../examples/logging.lua}}
```

## Sample Output

```
=== Basic Level Gating ===
[...] [DEBUG] this is a debug message (verbose)
[...] [INFO] server starting on port 8080
[...] [WARN] connection pool at 85% capacity
[...] [ERROR] failed to connect to db.example.com:5432

=== Child Loggers ===
[...] [INFO] [database] connection pool initialized (max=10)
[...] [INFO] [http] listening on 0.0.0.0:8080
[...] [DEBUG] [cache] LRU size=1000, ttl=300s
[...] [DEBUG] [http] GET /api/users
[...] [DEBUG] [cache] cache miss for key=users:list
[...] [DEBUG] [database] SELECT * FROM users LIMIT 50
[...] [INFO] [database] query returned 42 rows in 3.7ms
[...] [INFO] [cache] cached key=users:list ttl=300s
[...] [INFO] [http] 200 OK (5.2ms)

=== JSON Output Handler ===
{"ts":"...","level":"INFO","ctx":"app","msg":"application started"}
{"ts":"...","level":"WARN","ctx":"app","msg":"deprecated API called: /v1/users"}
{"ts":"...","level":"ERROR","ctx":"app","msg":"unhandled exception in request handler"}

=== Custom Timestamp (Elapsed) ===
[+0.0000s] [INFO] [bench] benchmark starting
[+0.0042s] [INFO] [bench] computed sum of 1..1M = 5e+11
[+0.0042s] [INFO] [bench] benchmark complete
```
