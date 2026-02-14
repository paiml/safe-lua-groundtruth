# Operator Overloading

Lua's metamethod system lets user-defined types behave like
built-in values. By implementing `__add`, `__sub`, `__mul`,
`__eq`, `__lt`, and friends on a metatable, you get natural
operator syntax (`a + b`, `v1 < v2`) while keeping full control
over type safety and immutability. This is the foundation of
every numeric and comparison type in the Lua ecosystem.

This example demonstrates two common patterns: an immutable
Vector2D with arithmetic operators (inspired by AwesomeWM
`gears.matrix` and Hammerspoon `geometry.lua`) and a Semver
type with comparison operators (inspired by lazy.nvim
`semver.lua` and xmake `hashset.lua`). Both types use safe-lua
defensive validation in constructors and guard contracts on
every operator to catch misuse at the point of call.

The key design principle is value-object semantics: every
arithmetic operation returns a NEW instance rather than mutating
an operand. This prevents aliasing bugs and makes operator
overloading safe to use in any context without worrying about
shared mutable state.

## Key Patterns

- **`__add` / `__sub`**: Binary arithmetic on two vectors,
  returning a new instance. Both operands validated.
- **`__mul` with type dispatch**: Supports both `scalar * vec`
  and `vec * scalar` by checking `type(a)` inside the
  metamethod. Mirrors AwesomeWM `gears.matrix.__mul`.
- **`__unm`**: Unary negation producing a new negated vector.
- **`__eq`**: Component-wise equality for both Vector2D and
  Semver. Lua only calls `__eq` when both operands share the
  same metatable.
- **`__lt` / `__le`**: Full ordering on Semver with
  major > minor > patch precedence. Enables `table.sort`
  directly on version lists.
- **`__tostring`**: Human-readable representation used by
  `tostring()` and in formatted output.
- **`__concat`**: Allows `"prefix " .. vec` by checking
  whether `lhs` is a string and delegating to `tostring`.
- **`Semver.parse`**: String-to-object constructor with
  `guard.contract` validation on the format.
- **`is_compatible`**: Semantic compatibility check (same major,
  self.minor >= other.minor) with logging.

## CB Checks Demonstrated

| Check  | Where                                          |
|--------|------------------------------------------------|
| CB-600 | `guard.contract` in `__mul` and `Semver.parse` |
| CB-601 | `guard.safe_get` for nil-safe version lookup   |
| CB-601 | `guard.assert_type` on every constructor       |
| CB-607 | `validate.Checker` colon-syntax in `Semver.new`|

## Source

```lua
{{#include ../../../examples/operator_overloading.lua}}
```

## Sample Output

```text
Operator Overloading in Lua 5.1
============================================================
Metamethod arithmetic & comparison from AwesomeWM,
lazy.nvim, xmake, and Hammerspoon — with safe-lua
defensive validation.

------------------------------------------------------------
Section: 1. Vector2D Arithmetic (__add, __sub, __mul, __unm)
------------------------------------------------------------
  Vector2D(3, 4) + Vector2D(1, 2) = Vector2D(4, 6)
  Vector2D(3, 4) - Vector2D(1, 2) = Vector2D(2, 2)
  2 * Vector2D(3, 4) = Vector2D(6, 8)
  Vector2D(1, 2) * 3 = Vector2D(3, 6)
  -Vector2D(3, 4) = Vector2D(-3, -4)
  length(Vector2D(3, 4)) = 5.0000
  dot(Vector2D(3, 4), Vector2D(1, 2)) = 11
  __concat: Result: Vector2D(4, 6)

------------------------------------------------------------
Section: 2. Vector2D Comparison (__eq, __tostring)
------------------------------------------------------------
  Vector2D(5, 10) == Vector2D(5, 10) ? true
  Vector2D(5, 10) == Vector2D(10, 5) ? false
  After u + v: u is still Vector2D(5, 10) (immutable)
  u + v produced new Vector2D(10, 20)
  u:x() = 5, u:y() = 10

------------------------------------------------------------
Section: 3. Semver Ordering (__eq, __lt, __le, __tostring)
------------------------------------------------------------
  1.0.0 == 1.0.0 ? true
  1.0.0 == 1.2.0 ? false
  1.0.0 <  1.2.0 ? true
  1.2.0 <  1.2.3 ? true
  1.2.3 <= 1.2.3 ? true
  1.2.3 <  2.0.0 ? true
  Semver.parse('3.14.159') = 3.14.159
  Sorted: 1.0.0 < 1.2.0 < 1.2.3 < 2.0.0
  v3:major()=1, v3:minor()=2, v3:patch()=3

------------------------------------------------------------
Section: 4. Semver Compatibility (is_compatible)
------------------------------------------------------------
  Library version: 2.5.0
  Requires >= 2.3.0 ? compatible = true
  Requires >= 2.7.0 ? compatible = false
  Requires >= 3.0.0 ? compatible = false
  safe_get found: 1.0.0
  safe_get missing: nil

============================================================
Metamethods demonstrated:
  __add, __sub, __mul, __unm  (Vector2D arithmetic)
  __eq, __lt, __le            (Semver comparison)
  __tostring, __concat        (string conversion)
============================================================
Done.
```

## Pattern Reference

| Pattern               | Projects                  | Key Metamethods         |
|-----------------------|---------------------------|-------------------------|
| Vector arithmetic     | AwesomeWM, Hammerspoon    | __add, __sub, __mul, __unm |
| Scalar dispatch       | AwesomeWM gears.matrix    | __mul with type check   |
| Value-object equality | xmake hashset             | __eq                    |
| Version ordering      | lazy.nvim semver          | __eq, __lt, __le        |
| String conversion     | AwesomeWM gears.matrix    | __tostring, __concat    |
| Parse constructor     | lazy.nvim semver          | guard.contract on format|
