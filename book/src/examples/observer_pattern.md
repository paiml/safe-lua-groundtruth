# Observer Pattern

Signal/event systems are ubiquitous in Lua projects. AwesomeWM's
`gears.object` provides `connect_signal`/`emit_signal` for widget
communication. Hammerspoon's `watchable.lua` implements KVO-style
change notification via `__newindex` interception. This example
demonstrates three observer variants — SignalEmitter, WeakEmitter,
and Observable — with safe-lua defensive validation throughout.

## Key Patterns

- **SignalEmitter**: Named signals with ordered handler dispatch,
  disconnect, once-listeners, and wildcard catch-all handlers
- **WeakEmitter**: Handlers stored in weak-value tables so they
  are automatically GC'd when no external references remain
- **Observable**: Proxy table using `__newindex` to detect writes
  and notify per-key watchers with old/new values (KVO pattern)
- **once()**: Handler wrapper that auto-disconnects after first call
- **Wildcard listener**: Receives all signals with signal name as
  first argument, useful for logging and debugging

## CB Checks Demonstrated

| Check  | Where                                          |
|--------|------------------------------------------------|
| CB-601 | `guard.assert_type` on signal names, handlers  |
| CB-601 | `guard.assert_not_nil` on persistent reference  |
| CB-600 | `guard.assert_type` on Observable key/handler   |
| CB-607 | `validate.Checker` colon-syntax in watchers     |

## Source

```lua
{{#include ../../../examples/observer_pattern.lua}}
```

## Sample Output

```text
Observer Pattern — Signal/Event Systems in Lua
============================================================
Patterns from AwesomeWM gears.object, Hammerspoon watchable,
and APISIX event bus — with safe-lua defensive validation.

------------------------------------------------------------
  1. SignalEmitter (AwesomeWM gears.object)
------------------------------------------------------------
Pattern: named signals with ordered handler dispatch.

  After emit: 2 messages received
    handler-A: first-event
    handler-B: first-event
  After disconnect + emit: 3 total messages
    Last: handler-B: second-event

------------------------------------------------------------
  2. once() and Wildcard Listeners
------------------------------------------------------------
Pattern: auto-disconnect after first call; catch-all listener.

  once-handler fired: booting (call #1)
  once-handler total calls: 1 (expected 1)
  Wildcard captured 3 signals: [init] [init] [ready]

------------------------------------------------------------
  3. WeakEmitter — Weak Listener References
------------------------------------------------------------
Pattern: handlers stored in weak tables; GC removes them.

  Before GC: 2 handlers
  After GC:  1 live handlers
  persistent: post-gc-event
  Only persistent handler fires after GC.

------------------------------------------------------------
  4. Observable Table (Hammerspoon watchable)
------------------------------------------------------------
Pattern: __newindex intercepts writes, notifies watchers.

  Current: host=localhost, port=8080
  Watcher: host: localhost -> prod.example.com
  Port watcher: port changed 8080 -> 443
  Total host-change notifications: 1
  Final host value: staging.example.com

============================================================
Done.
```

## Pattern Reference

| Pattern        | Source Project       | Mechanism              |
|----------------|----------------------|------------------------|
| SignalEmitter  | AwesomeWM gears.object | Named signal dispatch |
| WeakEmitter    | AwesomeWM weak_connect | Weak-value handler table |
| Observable     | Hammerspoon watchable  | __newindex proxy       |
| once()         | AwesomeWM, Node.js style | Auto-disconnect wrapper |
| Wildcard       | AwesomeWM, APISIX    | Catch-all listener array |
