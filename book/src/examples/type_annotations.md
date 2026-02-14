# Type Annotations

Lua has no built-in type system, but two competing
annotation standards have emerged across the ecosystem.
This example demonstrates both side-by-side, showing how
static annotations (which are just comments) pair with
runtime type checking via `guard` and `validate`.

## The Two Systems

**LuaLS / sumneko** is the modern standard, used by
lazy.nvim and growing in KOReader and lite-xl. It powers
lua-language-server, giving IDE features like hover docs,
type checking, and go-to-definition in Neovim and VSCode.
Annotations use the `---@` prefix.

**LDoc** is the legacy standard, used by AwesomeWM,
Hammerspoon, Penlight, and LuaSocket. It powers the
`ldoc` documentation generator, producing HTML/Markdown
API reference sites. Annotations use `-- @` with typed
parameter tags like `@tparam` and `@treturn`.

Both systems are pure comments with zero runtime effect.
Neither prevents type errors at execution time -- that is
where `guard.assert_type` and `validate.Checker` fill the
gap.

## What the Example Demonstrates

- **Point class** with LuaLS annotations: distance
  calculation, translation, defensive constructors
- **Rect class** with LDoc annotations: area, perimeter,
  containment, overlap, intersection
- **Shape interface** documented in both styles
- **Bounding box** computation from a point cloud
- **Collision detection** between rectangles
- **Runtime guard pairing**: annotations document intent,
  guards enforce it at call time
- **Comparison matrix** of syntax differences

## CB Checks Demonstrated

| Check  | Where                                  |
|--------|----------------------------------------|
| CB-600 | `guard.contract` on bounding box size  |
| CB-601 | `guard.assert_not_nil` on Point fields |
| CB-607 | `validate.Checker` colon-syntax        |

## Source

```lua
{{#include ../../../examples/type_annotations.lua}}
```

## Sample Output

```text
Type Annotations in Lua 5.1
============================================================
LuaLS (modern) vs LDoc (legacy) annotation systems,
paired with safe-lua runtime type checking.

------------------------------------------------------------
  LuaLS / sumneko Annotations (Point)
------------------------------------------------------------
  origin:   Point(0.0, 0.0)
  target:   Point(3.0, 4.0)
  distance: 5.00 (expected 5.00)
  moved:    Point(4.0, 3.0)

------------------------------------------------------------
  LDoc Annotations (Rect)
------------------------------------------------------------
  r1:          Rect(0.0, 0.0, 10.0 x 8.0)  area=80  perim=36
  r2:          Rect(5.0, 3.0, 12.0 x 6.0)  area=72  perim=36
  r1 center:   Point(5.0, 4.0)
  r2 center:   Point(11.0, 6.0)
  overlaps?    true
  intersection: Rect(5.0, 3.0, 5.0 x 5.0)  area=25
  r1 contains Point(3.0, 4.0)? true
  r1 contains Point(20.0, 20.0)? false

------------------------------------------------------------
  Combined: Bounding Box + Collision
------------------------------------------------------------
  Points:
    [1] Point(2.0, 1.0)
    [2] Point(8.0, 3.0)
    [3] Point(5.0, 9.0)
    [4] Point(1.0, 6.0)
  Bounding box: Rect(1.0, 1.0, 7.0 x 8.0)
  Bbox area:    56
  Query rect:   Rect(4.0, 4.0, 3.0 x 3.0)
  Overlaps bbox? true
  Intersection: Rect(4.0, 4.0, 3.0 x 3.0)  area=9

------------------------------------------------------------
  Runtime Checks Pair with Annotations
------------------------------------------------------------
  Annotations are comments: zero runtime cost.
  Runtime guards catch actual misuse at call time.

  Point.new(string, 5):  ok=false
    error: ...expected x to be number, got string
  Rect.new(0,0,-1,5):    ok=false
    error: ...w must be between 0.001 and 1000000000, got -1

  type(Point) = table  (annotations are invisible)
  type(Rect)  = table  (annotations are invisible)

------------------------------------------------------------
  Comparison Matrix: LuaLS vs LDoc
------------------------------------------------------------
  Feature          LuaLS / sumneko            LDoc
  ---------------  -------------------------  ------------------------
  Class            ---@class Name             -- @type Name
  Field            ---@field x number         -- @field x number desc
  Param            ---@param x number         -- @tparam number x desc
  Return           ---@return number          -- @treturn number desc
  Optional         ---@param x? number        -- @tparam[opt] number x
  Alias / Typedef  ---@alias Name type        -- @alias Name (limited)
  Generic          ---@generic T              Not supported
  Overload         ---@overload fun(a:T):R    Not supported
  Tooling          lua-language-server (IDE)   ldoc (doc generator)
  Projects         lazy.nvim, KOReader         AwesomeWM, Hammerspoon
  Runtime effect   None (comments only)        None (comments only)

============================================================
Done.
```

## Syntax Comparison

| Feature     | LuaLS / sumneko          | LDoc                     |
|-------------|--------------------------|--------------------------|
| Class       | `---@class Name`         | `-- @type Name`          |
| Field       | `---@field x number`     | `-- @field x number`     |
| Parameter   | `---@param x number`     | `-- @tparam number x`    |
| Return      | `---@return number`      | `-- @treturn number`     |
| Optional    | `---@param x? number`    | `-- @tparam[opt] number` |
| Alias       | `---@alias Name type`    | `-- @alias Name`         |
| Generic     | `---@generic T`          | Not supported            |
| Overload    | `---@overload fun():R`   | Not supported            |
| Tooling     | lua-language-server      | ldoc generator           |
| Projects    | lazy.nvim, KOReader      | AwesomeWM, Hammerspoon   |
