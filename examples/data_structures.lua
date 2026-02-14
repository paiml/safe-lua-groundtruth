#!/usr/bin/env lua5.1
--[[
  data_structures.lua — Example: Stack, Queue, Set, LRU Cache.
  Demonstrates defensive data structure construction in Lua 5.1
  using guard contracts, validate checks, and metatables. Patterns
  from xmake hashset.lua (set with __eq), APISIX LRU caches, and
  AwesomeWM gears.cache (weak-value cache with creation callback).

  Usage: lua5.1 examples/data_structures.lua
]]

package.path = "lib/?.lua;" .. package.path

local guard = require("safe.guard")
local validate = require("safe.validate")
local log = require("safe.log")

local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local string_format = string.format
local string_rep = string.rep
local table_sort = table.sort

log.set_level(log.INFO)
log.set_context("data-structures")

--- Print a section header.
--- @param title string
local function banner(title)
    guard.assert_type(title, "string", "title")
    io.write("\n" .. string_rep("-", 60) .. "\n")
    io.write(string_format("Section: %s\n", title))
    io.write(string_rep("-", 60) .. "\n")
end

-- ================================================================
-- 1. Stack — LIFO with array-style internal storage
-- ================================================================

local Stack = {}
local stack_mt = { __index = Stack }

--- Create a new empty stack.
--- @return table stack
function Stack.new()
    return setmetatable({ _data = {}, _count = 0 }, stack_mt)
end

--- Push a value onto the stack.
--- @param value any non-nil value
function Stack:push(value)
    guard.assert_not_nil(value, "value")
    self._count = self._count + 1
    self._data[self._count] = value
end

--- Pop the top value from the stack.
--- @return any|nil value or nil if empty
function Stack:pop()
    if self._count == 0 then
        return nil
    end
    local value = self._data[self._count]
    self._data[self._count] = nil
    self._count = self._count - 1
    return value
end

--- Peek at the top value without removing it.
--- @return any|nil value or nil if empty
function Stack:peek()
    if self._count == 0 then
        return nil
    end
    return self._data[self._count]
end

--- Return the number of elements in the stack.
--- @return number
function Stack:size()
    return self._count
end

--- Return true if the stack is empty.
--- @return boolean
function Stack:is_empty()
    return self._count == 0
end

-- ================================================================
-- 2. Queue — FIFO with O(1) dequeue using head/tail indices
-- ================================================================

local Queue = {}
local queue_mt = { __index = Queue }

--- Create a new empty queue.
--- @return table queue
function Queue.new()
    return setmetatable({ _data = {}, _head = 1, _tail = 0 }, queue_mt)
end

--- Add a value to the back of the queue.
--- @param value any non-nil value
function Queue:enqueue(value)
    guard.assert_not_nil(value, "value")
    self._tail = self._tail + 1
    self._data[self._tail] = value
end

--- Remove and return the front value. Returns nil if empty.
--- @return any|nil
function Queue:dequeue()
    if self._head > self._tail then
        return nil
    end
    local value = self._data[self._head]
    self._data[self._head] = nil
    self._head = self._head + 1
    -- Compact when head gets too far ahead (more than 1000 dead slots)
    if self._head > 1000 and self._head > self._tail then
        self._data = {}
        self._head = 1
        self._tail = 0
    end
    return value
end

--- Peek at the front value without removing it.
--- @return any|nil
function Queue:peek()
    if self._head > self._tail then
        return nil
    end
    return self._data[self._head]
end

--- Return the number of elements in the queue.
--- @return number
function Queue:size()
    if self._head > self._tail then
        return 0
    end
    return self._tail - self._head + 1
end

--- Return true if the queue is empty.
--- @return boolean
function Queue:is_empty()
    return self._head > self._tail
end

-- ================================================================
-- 3. Set — Hash set with union, intersection, difference, __eq
-- ================================================================

local Set = {}
local set_mt = {}
set_mt.__index = Set

--- Create a new set, optionally from an array of items.
--- @param items table|nil optional array of initial elements
--- @return table set
function Set.new(items)
    local self = setmetatable({ _items = {}, _count = 0 }, set_mt)
    if items ~= nil then
        guard.assert_type(items, "table", "items")
        for i = 1, #items do
            self:add(items[i])
        end
    end
    return self
end

--- Add an element to the set.
--- @param value any non-nil value
function Set:add(value)
    guard.assert_not_nil(value, "value")
    if not self._items[value] then
        self._items[value] = true
        self._count = self._count + 1
    end
end

--- Remove an element from the set.
--- @param value any
function Set:remove(value)
    if self._items[value] then
        self._items[value] = nil
        self._count = self._count - 1
    end
end

--- Check if the set contains a value.
--- @param value any
--- @return boolean
function Set:contains(value)
    return self._items[value] == true
end

--- Return the number of elements in the set.
--- @return number
function Set:size()
    return self._count
end

--- Return a sorted array of all elements.
--- @return table array
function Set:to_array()
    local arr = {}
    for k in pairs(self._items) do
        arr[#arr + 1] = k
    end
    table_sort(arr, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return arr
end

--- Return a new set containing all elements from both sets.
--- @param a table set
--- @param b table set
--- @return table set
function Set.union(a, b)
    guard.assert_type(a, "table", "a")
    guard.assert_type(b, "table", "b")
    local result = Set.new()
    for k in pairs(a._items) do
        result:add(k)
    end
    for k in pairs(b._items) do
        result:add(k)
    end
    return result
end

--- Return a new set containing only elements in both sets.
--- @param a table set
--- @param b table set
--- @return table set
function Set.intersection(a, b)
    guard.assert_type(a, "table", "a")
    guard.assert_type(b, "table", "b")
    local result = Set.new()
    for k in pairs(a._items) do
        if b._items[k] then
            result:add(k)
        end
    end
    return result
end

--- Return a new set with elements in a but not in b.
--- @param a table set
--- @param b table set
--- @return table set
function Set.difference(a, b)
    guard.assert_type(a, "table", "a")
    guard.assert_type(b, "table", "b")
    local result = Set.new()
    for k in pairs(a._items) do
        if not b._items[k] then
            result:add(k)
        end
    end
    return result
end

--- Equality metamethod: two sets are equal if they contain the same elements.
--- @param a table set
--- @param b table set
--- @return boolean
set_mt.__eq = function(a, b)
    if a._count ~= b._count then
        return false
    end
    for k in pairs(a._items) do
        if not b._items[k] then
            return false
        end
    end
    return true
end

--- String representation of the set.
--- @param self table set
--- @return string
set_mt.__tostring = function(self)
    local arr = self:to_array()
    local parts = {}
    for i = 1, #arr do
        parts[i] = tostring(arr[i])
    end
    return "Set{" .. table.concat(parts, ", ") .. "}"
end

-- ================================================================
-- 4. LRU Cache — Doubly-linked list + hash table
-- ================================================================

local LRU = {}
local lru_mt = { __index = LRU }

--- Create a new LRU cache with the given capacity.
--- @param capacity number maximum number of entries (must be > 0)
--- @return table lru
function LRU.new(capacity)
    guard.assert_type(capacity, "number", "capacity")
    guard.contract(capacity > 0, "capacity must be greater than 0")
    -- Sentinel nodes for doubly-linked list (head.next = MRU, tail.prev = LRU)
    local head = { key = nil, value = nil, prev = nil, next = nil }
    local tail = { key = nil, value = nil, prev = nil, next = nil }
    head.next = tail
    tail.prev = head
    return setmetatable({
        _capacity = capacity,
        _size = 0,
        _map = {},
        _head = head,
        _tail = tail,
    }, lru_mt)
end

--- Remove a node from the doubly-linked list.
--- @param node table
local function remove_node(node)
    node.prev.next = node.next
    node.next.prev = node.prev
end

--- Insert a node right after head (most recently used position).
--- @param self table lru cache
--- @param node table
local function insert_after_head(self, node)
    node.next = self._head.next
    node.prev = self._head
    self._head.next.prev = node
    self._head.next = node
end

--- Get a value from the cache. Returns nil on miss.
--- On hit, marks the entry as most recently used.
--- @param key any
--- @return any|nil
function LRU:get(key)
    local node = self._map[key]
    if not node then
        return nil
    end
    -- Move to front (most recently used)
    remove_node(node)
    insert_after_head(self, node)
    return node.value
end

--- Put a key-value pair into the cache.
--- If the key exists, updates the value and marks it as most recently used.
--- If at capacity, evicts the least recently used entry.
--- @param key any non-nil key
--- @param value any non-nil value
function LRU:put(key, value)
    guard.assert_not_nil(key, "key")
    guard.assert_not_nil(value, "value")

    local existing = self._map[key]
    if existing then
        -- Update existing entry and move to front
        existing.value = value
        remove_node(existing)
        insert_after_head(self, existing)
        return
    end

    -- Evict LRU entry if at capacity
    if self._size >= self._capacity then
        local lru_node = self._tail.prev
        remove_node(lru_node)
        self._map[lru_node.key] = nil
        self._size = self._size - 1
        log.debug("evicted key: %s", tostring(lru_node.key))
    end

    -- Insert new node at front
    local node = { key = key, value = value, prev = nil, next = nil }
    insert_after_head(self, node)
    self._map[key] = node
    self._size = self._size + 1
end

--- Return the current number of entries in the cache.
--- @return number
function LRU:size()
    return self._size
end

--- Return keys in order from most recently used to least recently used.
--- @return table array of keys
function LRU:keys()
    local result = {}
    local current = self._head.next
    while current ~= self._tail do
        result[#result + 1] = current.key
        current = current.next
    end
    return result
end

-- ================================================================
-- Demo functions
-- ================================================================

local function demo_stack()
    banner("1. Stack (LIFO)")
    io.write("Array-backed stack with push/pop/peek.\n\n")

    local s = Stack.new()
    guard.contract(s:is_empty(), "new stack must be empty")

    io.write("  Pushing: 10, 20, 30\n")
    s:push(10)
    s:push(20)
    s:push(30)
    io.write(string_format("  Size: %d\n", s:size()))
    io.write(string_format("  Peek: %s\n", tostring(s:peek())))

    local popped = s:pop()
    io.write(string_format("  Pop:  %s (LIFO order)\n", tostring(popped)))
    io.write(string_format("  Peek: %s (new top)\n", tostring(s:peek())))
    io.write(string_format("  Size: %d\n", s:size()))

    -- Drain remaining
    s:pop()
    s:pop()
    io.write(string_format("  After draining: empty=%s, pop=%s\n", tostring(s:is_empty()), tostring(s:pop())))
    log.info("stack demo complete")
end

local function demo_queue()
    banner("2. Queue (FIFO) with O(1) Dequeue")
    io.write("Head/tail index queue avoids table.remove(1) cost.\n\n")

    local q = Queue.new()
    guard.contract(q:is_empty(), "new queue must be empty")

    io.write("  Enqueue: A, B, C, D\n")
    q:enqueue("A")
    q:enqueue("B")
    q:enqueue("C")
    q:enqueue("D")
    io.write(string_format("  Size: %d\n", q:size()))
    io.write(string_format("  Peek (front): %s\n", tostring(q:peek())))

    local first = q:dequeue()
    local second = q:dequeue()
    io.write(string_format("  Dequeue: %s, %s (FIFO order)\n", tostring(first), tostring(second)))
    io.write(string_format("  Remaining size: %d\n", q:size()))
    io.write(string_format("  Peek (front): %s\n", tostring(q:peek())))

    -- Drain
    q:dequeue()
    q:dequeue()
    io.write(string_format("  After draining: empty=%s, dequeue=%s\n", tostring(q:is_empty()), tostring(q:dequeue())))
    log.info("queue demo complete")
end

local function demo_set_operations()
    banner("3. Set with Union, Intersection, Difference")
    io.write("Hash set using table keys for O(1) membership.\n\n")

    local fruits = Set.new({ "apple", "banana", "cherry", "date" })
    local citrus = Set.new({ "lemon", "lime", "cherry", "date" })

    io.write(string_format("  fruits: %s\n", tostring(fruits)))
    io.write(string_format("  citrus: %s\n", tostring(citrus)))
    io.write(string_format("  fruits:size() = %d\n", fruits:size()))

    -- Membership
    local ok, _ = validate.check_not_nil(fruits:contains("apple") and true or nil, "contains check")
    io.write(string_format("  fruits:contains('apple')  = %s\n", tostring(ok)))
    io.write(string_format("  fruits:contains('lemon')  = %s\n", tostring(fruits:contains("lemon"))))

    -- Set operations
    local u = Set.union(fruits, citrus)
    local inter = Set.intersection(fruits, citrus)
    local diff = Set.difference(fruits, citrus)

    io.write(string_format("  union:        %s\n", tostring(u)))
    io.write(string_format("  intersection: %s\n", tostring(inter)))
    io.write(string_format("  difference:   %s\n", tostring(diff)))

    -- Equality
    local copy = Set.new({ "apple", "banana", "cherry", "date" })
    io.write(string_format("  fruits == copy?  %s\n", tostring(fruits == copy)))
    io.write(string_format("  fruits == citrus? %s\n", tostring(fruits == citrus)))

    -- Remove
    fruits:remove("banana")
    io.write(string_format("  After remove('banana'): %s\n", tostring(fruits)))
    log.info("set demo complete")
end

local function demo_lru_cache()
    banner("4. LRU Cache with O(1) Operations")
    io.write("Doubly-linked list + hash table for O(1) get/put/evict.\n\n")

    local cache = LRU.new(3)
    local c = validate.Checker:new()
    c:check_type(cache:size(), "number", "cache size")
    c:assert()

    io.write("  Capacity: 3\n")
    io.write("  Put: a=1, b=2, c=3\n")
    cache:put("a", 1)
    cache:put("b", 2)
    cache:put("c", 3)
    io.write(string_format("  Size: %d\n", cache:size()))

    local keys = cache:keys()
    io.write(string_format("  MRU -> LRU: %s\n", table.concat(keys, ", ")))

    -- Access 'a' to make it most recently used
    local val = cache:get("a")
    io.write(string_format("\n  get('a') = %s (moves to front)\n", tostring(val)))
    keys = cache:keys()
    io.write(string_format("  MRU -> LRU: %s\n", table.concat(keys, ", ")))

    -- Eviction: put 'd' should evict 'b' (least recently used)
    io.write("\n  Put: d=4 (capacity exceeded, evicts LRU)\n")
    cache:put("d", 4)
    io.write(string_format("  Size: %d\n", cache:size()))
    keys = cache:keys()
    io.write(string_format("  MRU -> LRU: %s\n", table.concat(keys, ", ")))

    local evicted = cache:get("b")
    io.write(string_format("  get('b') = %s (was evicted)\n", tostring(evicted)))

    -- Update existing key
    io.write("\n  Put: a=100 (update existing)\n")
    cache:put("a", 100)
    io.write(string_format("  get('a') = %s\n", tostring(cache:get("a"))))
    keys = cache:keys()
    io.write(string_format("  MRU -> LRU: %s\n", table.concat(keys, ", ")))
    log.info("lru cache demo complete")
end

-- ================================================================
-- Main
-- ================================================================

local function main(_args)
    io.write("Data Structures in Lua 5.1\n")
    io.write(string_rep("=", 60) .. "\n")
    io.write("Stack, Queue, Set, and LRU Cache with defensive patterns\n")
    io.write("from xmake, APISIX, and AwesomeWM.\n")

    demo_stack()
    demo_queue()
    demo_set_operations()
    demo_lru_cache()

    io.write("\n" .. string_rep("=", 60) .. "\n")
    log.info("all data structure demos complete")
    io.write("Done.\n")
    return 0
end

os.exit(main(arg))
