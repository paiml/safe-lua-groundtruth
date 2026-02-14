local perf = require("safe.perf")

describe("safe.perf", function()
    describe("concat_safe", function()
        it("concatenates array of strings", function()
            assert.are.equal("abc", perf.concat_safe({ "a", "b", "c" }))
        end)

        it("handles empty array", function()
            assert.are.equal("", perf.concat_safe({}))
        end)

        it("handles single element", function()
            assert.are.equal("hello", perf.concat_safe({ "hello" }))
        end)

        it("handles strings with spaces", function()
            assert.are.equal("hello world", perf.concat_safe({ "hello", " ", "world" }))
        end)
    end)

    describe("concat_unsafe", function()
        it("produces same result as concat_safe", function()
            local parts = { "a", "b", "c" }
            assert.are.equal(perf.concat_safe(parts), perf.concat_unsafe(parts))
        end)

        it("handles empty array", function()
            assert.are.equal("", perf.concat_unsafe({}))
        end)

        it("handles single element", function()
            assert.are.equal("hello", perf.concat_unsafe({ "hello" }))
        end)
    end)

    describe("build_string", function()
        it("repeats character n times", function()
            assert.are.equal("aaaa", perf.build_string(4, "a"))
        end)

        it("repeats multi-char string", function()
            assert.are.equal("abab", perf.build_string(2, "ab"))
        end)

        it("handles zero repetitions", function()
            assert.are.equal("", perf.build_string(0, "x"))
        end)

        it("handles single repetition", function()
            assert.are.equal("x", perf.build_string(1, "x"))
        end)
    end)

    describe("numeric_for_sum", function()
        it("sums array of numbers", function()
            assert.are.equal(10, perf.numeric_for_sum({ 1, 2, 3, 4 }))
        end)

        it("handles empty array", function()
            assert.are.equal(0, perf.numeric_for_sum({}))
        end)

        it("handles single element", function()
            assert.are.equal(42, perf.numeric_for_sum({ 42 }))
        end)

        it("handles negative numbers", function()
            assert.are.equal(0, perf.numeric_for_sum({ -1, 1 }))
        end)
    end)

    describe("ipairs_sum", function()
        it("sums array of numbers", function()
            assert.are.equal(10, perf.ipairs_sum({ 1, 2, 3, 4 }))
        end)

        it("handles empty array", function()
            assert.are.equal(0, perf.ipairs_sum({}))
        end)

        it("produces same result as numeric_for_sum", function()
            local tbl = { 5, 10, 15, 20 }
            assert.are.equal(perf.numeric_for_sum(tbl), perf.ipairs_sum(tbl))
        end)
    end)

    describe("reuse_table", function()
        it("fills table with 1..n", function()
            local t = {}
            perf.reuse_table(t, 5)
            assert.are.same({ 1, 2, 3, 4, 5 }, t)
        end)

        it("clears previous contents", function()
            local t = { 10, 20, 30, 40, 50 }
            perf.reuse_table(t, 3)
            assert.are.same({ 1, 2, 3 }, t)
        end)

        it("returns the same table", function()
            local t = {}
            local result = perf.reuse_table(t, 3)
            assert.are.equal(t, result)
        end)

        it("handles zero fill", function()
            local t = { 1, 2, 3 }
            perf.reuse_table(t, 0)
            assert.are.same({}, t)
        end)
    end)

    describe("format_many", function()
        it("formats all items", function()
            local result = perf.format_many("item_%d", { 1, 2, 3 })
            assert.are.same({ "item_1", "item_2", "item_3" }, result)
        end)

        it("handles empty list", function()
            local result = perf.format_many("x_%s", {})
            assert.are.same({}, result)
        end)

        it("handles string template", function()
            local result = perf.format_many("[%s]", { "a", "b" })
            assert.are.same({ "[a]", "[b]" }, result)
        end)

        it("handles float template", function()
            local result = perf.format_many("%.2f", { 1.5, 2.75 })
            assert.are.same({ "1.50", "2.75" }, result)
        end)
    end)
end)
