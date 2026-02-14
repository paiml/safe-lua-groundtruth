# Data Structures

Lua tables are the universal data structure, but they lack
built-in stacks, queues, sets, and caches. Implementing these
correctly in Lua 5.1 requires careful attention to algorithmic
complexity (avoiding O(n) `table.remove(1)` in queues),
metatable-driven equality (`__eq` for sets), and eviction
policies (doubly-linked lists for LRU caches).

This example builds four production-quality data structures
with defensive validation in every constructor and mutator,
following patterns from xmake's `hashset.lua`, APISIX LRU
caches, and AwesomeWM's `gears.cache`.

## Key Patterns

- **Stack (LIFO)**: Array-backed with a count index; `push`
  appends, `pop` removes from the end. O(1) for all operations.
- **Queue (FIFO)**: Head/tail index pair avoids the O(n) cost
  of `table.remove(1)`. Compacts dead slots when head drifts.
- **Set**: Hash table keyed by element value for O(1) membership.
  `__eq` metamethod compares element-by-element. `__tostring`
  for readable output. Static `union`/`intersection`/`difference`.
- **LRU Cache**: Doubly-linked list for O(1) move-to-front,
  hash table for O(1) key lookup. Sentinel head/tail nodes
  simplify boundary logic. Evicts least recently used on overflow.

## CB Checks Demonstrated

| Check  | Where                                         |
|--------|-----------------------------------------------|
| CB-600 | `guard.contract` on capacity > 0 in LRU.new   |
| CB-601 | `guard.assert_not_nil` on push/enqueue/put     |
| CB-602 | `guard.assert_type` on constructor parameters  |
| CB-607 | `validate.Checker` colon-syntax in LRU demo    |

## Source

```lua
{{#include ../../../examples/data_structures.lua}}
```

## Sample Output

```text
Data Structures in Lua 5.1
============================================================
Stack, Queue, Set, and LRU Cache with defensive patterns
from xmake, APISIX, and AwesomeWM.

------------------------------------------------------------
Section: 1. Stack (LIFO)
------------------------------------------------------------
Array-backed stack with push/pop/peek.

  Pushing: 10, 20, 30
  Size: 3
  Peek: 30
  Pop:  30 (LIFO order)
  Peek: 20 (new top)
  Size: 2
  After draining: empty=true, pop=nil

------------------------------------------------------------
Section: 2. Queue (FIFO) with O(1) Dequeue
------------------------------------------------------------
Head/tail index queue avoids table.remove(1) cost.

  Enqueue: A, B, C, D
  Size: 4
  Peek (front): A
  Dequeue: A, B (FIFO order)
  Remaining size: 2
  Peek (front): C
  After draining: empty=true, dequeue=nil

------------------------------------------------------------
Section: 3. Set with Union, Intersection, Difference
------------------------------------------------------------
Hash set using table keys for O(1) membership.

  fruits: Set{apple, banana, cherry, date}
  citrus: Set{cherry, date, lemon, lime}
  fruits:size() = 4
  fruits:contains('apple')  = true
  fruits:contains('lemon')  = false
  union:        Set{apple, banana, cherry, date, lemon, lime}
  intersection: Set{cherry, date}
  difference:   Set{apple, banana}
  fruits == copy?  true
  fruits == citrus? false
  After remove('banana'): Set{apple, cherry, date}

------------------------------------------------------------
Section: 4. LRU Cache with O(1) Operations
------------------------------------------------------------
Doubly-linked list + hash table for O(1) get/put/evict.

  Capacity: 3
  Put: a=1, b=2, c=3
  Size: 3
  MRU -> LRU: c, b, a

  get('a') = 1 (moves to front)
  MRU -> LRU: a, c, b

  Put: d=4 (capacity exceeded, evicts LRU)
  Size: 3
  MRU -> LRU: d, a, c
  get('b') = nil (was evicted)

  Put: a=100 (update existing)
  get('a') = 100
  MRU -> LRU: a, d, c

============================================================
Done.
```

## Pattern Reference

| Structure | Complexity   | Source Projects        | Key Technique           |
|-----------|-------------|------------------------|-------------------------|
| Stack     | O(1) all    | General Lua idiom      | Array + count index     |
| Queue     | O(1) all    | APISIX, Kong           | Head/tail index pair    |
| Set       | O(1) lookup | xmake hashset.lua      | Table keys + __eq       |
| LRU Cache | O(1) all    | APISIX, AwesomeWM      | Linked list + hash map  |
