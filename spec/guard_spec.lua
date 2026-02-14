local guard = require("safe.guard")

describe("safe.guard", function()
    describe("safe_get", function()
        it("returns value for valid path", function()
            local t = { a = { b = { c = 42 } } }
            assert.are.equal(42, guard.safe_get(t, "a", "b", "c"))
        end)

        it("returns nil for missing intermediate key", function()
            local t = { a = { b = 1 } }
            assert.is_nil(guard.safe_get(t, "a", "x", "c"))
        end)

        it("returns nil for nil table", function()
            assert.is_nil(guard.safe_get(nil, "a"))
        end)

        it("returns table itself with no keys", function()
            local t = { a = 1 }
            assert.are.equal(t, guard.safe_get(t))
        end)

        it("returns nil when traversing non-table", function()
            local t = { a = "string" }
            assert.is_nil(guard.safe_get(t, "a", "b"))
        end)

        it("handles numeric keys", function()
            local t = { [1] = { [2] = "found" } }
            assert.are.equal("found", guard.safe_get(t, 1, 2))
        end)

        it("returns false values correctly", function()
            local t = { a = { b = false } }
            assert.are.equal(false, guard.safe_get(t, "a", "b"))
        end)
    end)

    describe("assert_type", function()
        it("passes for correct type", function()
            assert.has_no.errors(function()
                guard.assert_type("hello", "string", "arg1")
            end)
        end)

        it("errors for wrong type", function()
            assert.has.errors(function()
                guard.assert_type(42, "string", "arg1")
            end, "expected arg1 to be string, got number")
        end)

        it("works with table type", function()
            assert.has_no.errors(function()
                guard.assert_type({}, "table", "data")
            end)
        end)

        it("works with nil type", function()
            assert.has_no.errors(function()
                guard.assert_type(nil, "nil", "opt")
            end)
        end)

        it("accepts custom stack level", function()
            assert.has.errors(function()
                guard.assert_type(42, "string", "arg1", 3)
            end)
        end)
    end)

    describe("assert_not_nil", function()
        it("passes for non-nil value", function()
            assert.has_no.errors(function()
                guard.assert_not_nil(42, "value")
            end)
        end)

        it("passes for false", function()
            assert.has_no.errors(function()
                guard.assert_not_nil(false, "flag")
            end)
        end)

        it("errors for nil", function()
            assert.has.errors(function()
                guard.assert_not_nil(nil, "required")
            end, "expected required to be non-nil")
        end)

        it("accepts custom stack level", function()
            assert.has.errors(function()
                guard.assert_not_nil(nil, "val", 3)
            end)
        end)
    end)

    describe("freeze", function()
        it("allows reading existing keys", function()
            local t = { a = 1, b = 2 }
            local frozen = guard.freeze(t)
            assert.are.equal(1, frozen.a)
            assert.are.equal(2, frozen.b)
        end)

        it("returns nil for missing keys", function()
            local frozen = guard.freeze({ a = 1 })
            assert.is_nil(frozen.x)
        end)

        it("errors on write", function()
            local frozen = guard.freeze({ a = 1 })
            assert.has.errors(function()
                frozen.a = 2
            end, "attempt to modify frozen table key: a")
        end)

        it("errors on new key write", function()
            local frozen = guard.freeze({})
            assert.has.errors(function()
                frozen.new_key = 1
            end, "attempt to modify frozen table key: new_key")
        end)

        it("reads through to underlying table values", function()
            local frozen = guard.freeze({ 10, 20, 30 })
            assert.are.equal(10, frozen[1])
            assert.are.equal(20, frozen[2])
            assert.are.equal(30, frozen[3])
        end)
    end)

    describe("protect_globals", function()
        it("allows access to declared globals", function()
            local env = { foo = 42 }
            guard.protect_globals(env)
            assert.are.equal(42, env.foo)
        end)

        it("allows writing to declared globals", function()
            local env = { foo = 42 }
            guard.protect_globals(env)
            env.foo = 99
            assert.are.equal(99, env.foo)
        end)

        it("errors on access to undeclared global", function()
            local env = { foo = 42 }
            guard.protect_globals(env)
            assert.has.errors(function()
                local _ = env.bar
            end, "access to undeclared global: bar")
        end)

        it("errors on assignment to undeclared global", function()
            local env = { foo = 42 }
            guard.protect_globals(env)
            assert.has.errors(function()
                env.bar = 1
            end, "assignment to undeclared global: bar")
        end)

        it("allows writing via rawset then re-setting declared key", function()
            local env = { foo = 42 }
            guard.protect_globals(env)
            -- Remove key from raw table so __newindex fires on reassignment
            rawset(env, "foo", nil)
            env.foo = 100
            assert.are.equal(100, env.foo)
        end)

        it("returns nil for declared key that was rawset to nil", function()
            local env = { foo = 42 }
            guard.protect_globals(env)
            rawset(env, "foo", nil)
            -- __index fires: key is declared, so returns nil without error
            assert.is_nil(env.foo)
        end)
    end)

    describe("contract", function()
        it("passes for truthy condition", function()
            assert.has_no.errors(function()
                guard.contract(true, "should pass")
            end)
        end)

        it("passes for non-nil truthy values", function()
            assert.has_no.errors(function()
                guard.contract(42, "should pass")
            end)
        end)

        it("errors for false", function()
            assert.has.errors(function()
                guard.contract(false, "contract violated")
            end, "contract violated")
        end)

        it("errors for nil", function()
            assert.has.errors(function()
                guard.contract(nil, "nil violation")
            end, "nil violation")
        end)

        it("accepts custom stack level", function()
            assert.has.errors(function()
                guard.contract(false, "msg", 3)
            end)
        end)
    end)

    describe("enum", function()
        it("creates lookup from string list", function()
            local colors = guard.enum({ "RED", "GREEN", "BLUE" })
            assert.are.equal("RED", colors.RED)
            assert.are.equal("GREEN", colors.GREEN)
            assert.are.equal("BLUE", colors.BLUE)
        end)

        it("returns nil for unknown keys", function()
            local colors = guard.enum({ "RED" })
            assert.is_nil(colors.YELLOW)
        end)

        it("is frozen", function()
            local colors = guard.enum({ "RED" })
            assert.has.errors(function()
                colors.NEW = "NEW"
            end)
        end)

        it("works with empty list", function()
            local empty = guard.enum({})
            assert.has.errors(function()
                empty.anything = true
            end)
        end)
    end)
end)
