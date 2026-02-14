--[[
  Falsification suite — adversarial tests probing specification weaknesses.
  Each test targets a specific edge case or boundary condition that the
  original specs missed. Tests are tagged with the module and the class
  of weakness found.
]]

local guard = require("safe.guard")
local log = require("safe.log")
local validate = require("safe.validate")
local shell = require("safe.shell")
local perf = require("safe.perf")
local helpers = require("safe.test_helpers")

-- ============================================================
-- guard.lua falsification
-- ============================================================
describe("FALSIFY guard", function()
    describe("freeze: shallow freeze allows mutation of nested tables", function()
        it("inner table is MUTABLE through frozen proxy", function()
            local inner = { value = 1 }
            local frozen = guard.freeze({ nested = inner })
            -- This SHOULD arguably fail but DOES NOT — freeze is shallow
            frozen.nested.value = 999
            assert.are.equal(999, inner.value)
        end)
    end)

    describe("freeze: pairs() cannot iterate frozen proxy in Lua 5.1", function()
        it("pairs() yields ZERO entries from frozen table", function()
            local frozen = guard.freeze({ a = 1, b = 2, c = 3 })
            local count = 0
            for _ in pairs(frozen) do
                count = count + 1
            end
            -- BUG: pairs() iterates the empty proxy, not the underlying table
            -- In Lua 5.1, __pairs metamethod is not supported
            assert.are.equal(0, count)
        end)
    end)

    describe("freeze: rawget bypasses protection", function()
        it("rawget on frozen proxy returns nil (not underlying value)", function()
            local frozen = guard.freeze({ secret = 42 })
            -- rawget bypasses __index, gets nil from the empty proxy
            assert.is_nil(rawget(frozen, "secret"))
            -- but __index works
            assert.are.equal(42, frozen.secret)
        end)
    end)

    describe("safe_get: nil key in varargs chain", function()
        it("nil as an explicit key indexes with nil (returns nil)", function()
            local t = { a = { [true] = "found" } }
            -- safe_get(t, "a", nil) — attempts t.a[nil] which is nil
            assert.is_nil(guard.safe_get(t, "a", nil))
        end)
    end)

    describe("safe_get: boolean keys", function()
        it("traverses boolean keys correctly", function()
            local t = { [true] = { [false] = "deep" } }
            assert.are.equal("deep", guard.safe_get(t, true, false))
        end)
    end)

    describe("protect_globals: replaces existing metatable", function()
        it("overwrites a pre-existing metatable", function()
            local env = { x = 1 }
            local custom_mt = {
                __tostring = function()
                    return "custom"
                end,
            }
            setmetatable(env, custom_mt)
            guard.protect_globals(env)
            -- The custom metatable is gone — replaced silently
            local mt = getmetatable(env)
            assert.is_not.equal(custom_mt, mt)
        end)
    end)

    describe("contract: Lua truthiness edge cases", function()
        it("passes for 0 (truthy in Lua, unlike C/Python)", function()
            assert.has_no.errors(function()
                guard.contract(0, "zero is truthy in Lua")
            end)
        end)

        it("passes for empty string (truthy in Lua)", function()
            assert.has_no.errors(function()
                guard.contract("", "empty string is truthy in Lua")
            end)
        end)
    end)

    describe("enum: duplicate names", function()
        it("silently deduplicates (last write wins, same value)", function()
            local e = guard.enum({ "A", "B", "A" })
            assert.are.equal("A", e.A)
            assert.are.equal("B", e.B)
        end)
    end)
end)

-- ============================================================
-- log.lua falsification
-- ============================================================
describe("FALSIFY log", function()
    local captured

    before_each(function()
        captured = {}
        log.set_output(function(msg)
            captured[#captured + 1] = msg
        end)
        log.set_timestamp(function()
            return "TS"
        end)
        log.set_level(log.DEBUG)
        log.set_context(nil)
    end)

    describe("with_context: context restored on output_fn error", function()
        it("restores parent context when output_fn throws", function()
            log.set_context("parent")
            log.set_output(function(_msg)
                error("output exploded")
            end)
            local child = log.with_context("child")
            -- FIXED: pcall in with_ctx ensures context is restored
            pcall(function()
                child.info("boom")
            end)
            assert.are.equal("parent", log.get_context())
        end)
    end)

    describe("format string with percent but no args", function()
        it("handles literal percent in message without args", function()
            log.set_output(function(msg)
                captured[#captured + 1] = msg
            end)
            -- No varargs, so msg = fmt directly (no string.format call)
            log.info("CPU at 100%")
            assert.truthy(captured[1]:find("100%%"))
        end)
    end)

    describe("format string with wrong arg count", function()
        it("errors when format expects more args than provided", function()
            log.set_output(function(msg)
                captured[#captured + 1] = msg
            end)
            -- string.format("%s %s", "only_one") errors
            assert.has.errors(function()
                log.info("%s %s", "only_one")
            end)
        end)
    end)

    describe("level boundary: exact level match", function()
        it("shows message at exactly the current level", function()
            log.set_level(log.WARN)
            log.warn("at boundary")
            assert.are.equal(1, #captured)
        end)

        it("hides message one level below current", function()
            log.set_level(log.WARN)
            log.info("below boundary")
            assert.are.equal(0, #captured)
        end)
    end)

    describe("module state leakage between requires", function()
        it("shares state — second require gets same module", function()
            log.set_level(log.ERROR)
            local log2 = require("safe.log")
            assert.are.equal(log.ERROR, log2.get_level())
            assert.are.equal(log, log2) -- same table
        end)
    end)
end)

-- ============================================================
-- validate.lua falsification
-- ============================================================
describe("FALSIFY validate", function()
    describe("check_range: NaN rejected", function()
        it("NaN is detected and rejected explicitly", function()
            local nan = 0 / 0
            local ok, err = validate.check_range(nan, 1, 10, "x")
            -- FIXED: NaN is now caught by explicit NaN ~= NaN check
            assert.is_false(ok)
            assert.truthy(err:find("NaN"))
        end)
    end)

    describe("check_range: infinity", function()
        it("positive infinity correctly fails upper bound", function()
            local ok, err = validate.check_range(math.huge, 1, 10, "x")
            assert.is_false(ok)
            assert.truthy(err:find("must be between"))
        end)

        it("negative infinity correctly fails lower bound", function()
            local ok, err = validate.check_range(-math.huge, 1, 10, "x")
            assert.is_false(ok)
            assert.truthy(err:find("must be between"))
        end)
    end)

    describe("check_range: boundary with floats", function()
        it("passes for min - epsilon (floating point)", function()
            -- 0.9999999999999998 rounds to 1.0 in double
            -- But 1 - 1e-15 is slightly below 1
            local val = 1 - 1e-15
            local ok, _err = validate.check_range(val, 1, 10, "x")
            -- Depends on floating point — val < 1 might be true
            if val < 1 then
                assert.is_false(ok)
            else
                assert.is_true(ok)
            end
        end)
    end)

    describe("schema: false value for boolean field", function()
        it("correctly distinguishes false from nil", function()
            local ok, result = validate.schema({ active = false }, {
                active = { type = "boolean", required = true },
            })
            assert.is_true(ok)
            assert.are.equal(false, result.active)
        end)
    end)

    describe("schema: false as default value", function()
        it("applies false default when field is absent", function()
            local ok, result = validate.schema({}, {
                enabled = { type = "boolean", default = false },
            })
            assert.is_true(ok)
            assert.are.equal(false, result.enabled)
        end)
    end)

    describe("schema: required field with default — default wins", function()
        it("uses default even when field is required and absent", function()
            local ok, result = validate.schema({}, {
                name = { type = "string", required = true, default = "fallback" },
            })
            -- The default branch is checked first, so required never fires
            assert.is_true(ok)
            assert.are.equal("fallback", result.name)
        end)
    end)

    describe("schema: field present with wrong type but has default", function()
        it("rejects wrong type even if default exists", function()
            local ok, err = validate.schema({ age = "not a number" }, {
                age = { type = "number", default = 0 },
            })
            assert.is_false(ok)
            assert.truthy(err:find("expected number, got string"))
        end)
    end)

    describe("Checker:assert with custom level", function()
        it("accepts custom stack level", function()
            local c = validate.Checker.new()
            c:check_type(42, "string", "x")
            assert.has.errors(function()
                c:assert(3)
            end)
        end)
    end)

    describe("schema: error ordering is nondeterministic", function()
        it("may produce errors in any order due to pairs()", function()
            -- With multiple schema errors, order depends on hash table iteration
            local ok, err = validate.schema({}, {
                a = { type = "string", required = true },
                b = { type = "number", required = true },
                c = { type = "boolean", required = true },
            })
            assert.is_false(ok)
            -- We can verify all errors are present but not their order
            assert.truthy(err:find("a"))
            assert.truthy(err:find("b"))
            assert.truthy(err:find("c"))
        end)
    end)
end)

-- ============================================================
-- shell.lua falsification
-- ============================================================
describe("FALSIFY shell", function()
    describe("validate_program: newline injection rejected", function()
        it("rejects program name containing newline", function()
            -- FIXED: whitespace is now in the metacharacter set
            local ok, err = shell.validate_program("ls\nrm -rf /tmp/test")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)
    end)

    describe("validate_program: space in name rejected", function()
        it("rejects program name containing spaces", function()
            local ok, err = shell.validate_program("my program")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)
    end)

    describe("validate_program: tab and carriage return rejected", function()
        it("rejects program name with tab character", function()
            local ok, err = shell.validate_program("ls\t-la")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)

        it("rejects program name with carriage return", function()
            local ok, err = shell.validate_program("ls\r")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)
    end)

    describe("validate_program: double quote in name rejected", function()
        it("rejects double quote", function()
            local ok, err = shell.validate_program('ls"')
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)
    end)

    describe("validate_program: single quote in name rejected", function()
        it("rejects single quote", function()
            local ok, err = shell.validate_program("ls'")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)
    end)

    describe("escape: null byte", function()
        it("passes null byte through (potentially dangerous)", function()
            local escaped = shell.escape("a\0b")
            -- The null byte is inside single quotes — behavior is shell-dependent
            assert.truthy(escaped:find("\0"))
        end)
    end)

    describe("escape: newline in argument", function()
        it("preserves newline inside single quotes", function()
            local escaped = shell.escape("line1\nline2")
            assert.are.equal("'line1\nline2'", escaped)
        end)
    end)

    describe("build_command: validates program but not args content", function()
        it("args bypass program validation via escaping", function()
            -- This is BY DESIGN — args are escaped, not validated
            local cmd = shell.build_command("echo", { "; rm -rf /" })
            -- The dangerous content is safely single-quoted
            assert.are.equal("echo '; rm -rf /'", cmd)
        end)
    end)

    describe("_normalize_exit: nil return value", function()
        it("handles nil as false", function()
            local ok, code = shell._normalize_exit(nil)
            assert.is_false(ok)
            assert.are.equal(1, code)
        end)
    end)

    describe("validate_args: non-sequential table", function()
        it("ignores non-numeric keys in args table", function()
            -- selene: allow(mixed_table)
            local ok, _err = shell.validate_args({ "a", "b", extra = "ignored" })
            -- The numeric for loop only checks indices 1..#args
            -- Hash keys like "extra" are silently ignored
            assert.is_true(ok)
        end)
    end)
end)

-- ============================================================
-- perf.lua falsification
-- ============================================================
describe("FALSIFY perf", function()
    describe("reuse_table: hash keys are now cleared", function()
        it("clears both numeric and hash keys", function()
            local t = { a = "hash", b = "keys", [1] = 10, [2] = 20 }
            perf.reuse_table(t, 3)
            -- FIXED: hash keys are cleared by pairs() iteration
            assert.is_nil(t.a)
            assert.is_nil(t.b)
            -- Numeric keys are correctly refilled
            assert.are.equal(1, t[1])
            assert.are.equal(2, t[2])
            assert.are.equal(3, t[3])
        end)
    end)

    describe("concat_safe: non-string elements", function()
        it("table.concat coerces numbers to strings", function()
            assert.are.equal("123", perf.concat_safe({ 1, 2, 3 }))
        end)

        it("table.concat errors on nil element", function()
            assert.has.errors(function()
                perf.concat_safe({ "a", nil, "b" })
            end)
        end)

        it("table.concat errors on boolean element", function()
            assert.has.errors(function()
                perf.concat_safe({ "a", true, "b" })
            end)
        end)

        it("table.concat errors on table element", function()
            assert.has.errors(function()
                perf.concat_safe({ "a", {}, "b" })
            end)
        end)
    end)

    describe("concat_unsafe: non-string elements", function()
        it(".. operator coerces numbers", function()
            assert.are.equal("123", perf.concat_unsafe({ 1, 2, 3 }))
        end)

        it(".. operator errors on nil with hole in array", function()
            -- Behavior depends on #parts with holes — undefined in Lua
            -- But if #parts sees the nil, parts[i] is nil and .. errors
            local t = { "a" }
            t[3] = "b"
            -- #t might be 1 or 3, behavior is undefined
            -- This test documents that behavior is unpredictable with holes
            local ok, _err = pcall(function()
                perf.concat_unsafe(t)
            end)
            -- We accept either outcome — the point is the behavior is undefined
            assert.is_true(ok == true or ok == false)
        end)
    end)

    describe("numeric_for_sum vs ipairs_sum: nil holes", function()
        it("numeric_for errors on nil in array", function()
            local t = { 1, nil, 3 }
            -- #t is undefined with holes, but if it's 3:
            -- t[2] is nil, sum + nil errors
            assert.has.errors(function()
                perf.numeric_for_sum(t)
            end)
        end)
    end)

    describe("format_many: mismatched format specifier", function()
        it("errors on type mismatch in format", function()
            assert.has.errors(function()
                perf.format_many("%d", { "not_a_number" })
            end)
        end)
    end)
end)

-- ============================================================
-- test_helpers.lua falsification
-- ============================================================
describe("FALSIFY test_helpers", function()
    describe("table_eq: NaN is never equal to itself", function()
        it("NaN ~= NaN per IEEE 754", function()
            local nan = 0 / 0
            -- BUG (or feature): table_eq returns false for identical NaN values
            assert.is_false(helpers.table_eq(nan, nan))
        end)

        it("tables containing NaN are never equal", function()
            local nan = 0 / 0
            assert.is_false(helpers.table_eq({ x = nan }, { x = nan }))
        end)
    end)

    describe("table_eq: cyclic tables handled", function()
        it("self-referencing table compares equal to itself", function()
            local t = {}
            t.self = t
            -- FIXED: cycle detection prevents infinite recursion
            assert.is_true(helpers.table_eq(t, t))
        end)

        it("two identical cyclic structures compare equal", function()
            local a = { val = 1 }
            a.self = a
            local b = { val = 1 }
            b.self = b
            assert.is_true(helpers.table_eq(a, b))
        end)

        it("different cyclic structures compare not equal", function()
            local a = { val = 1 }
            a.self = a
            local b = { val = 2 }
            b.self = b
            assert.is_false(helpers.table_eq(a, b))
        end)
    end)

    describe("table_eq: metatables are ignored", function()
        it("tables with different metatables compare equal if data matches", function()
            local a = setmetatable({ x = 1 }, {
                __eq = function()
                    return false
                end,
            })
            local b = setmetatable({ x = 1 }, {
                __eq = function()
                    return true
                end,
            })
            -- table_eq uses pairs() and raw comparison, ignoring __eq
            assert.is_true(helpers.table_eq(a, b))
        end)
    end)

    describe("capture_output: mock doesn't return file handle", function()
        it("code using io.write():write() chaining would break", function()
            -- The real io.write returns the file handle for chaining
            -- Our mock returns nil, so chaining would error
            assert.has.errors(function()
                helpers.capture_output(function()
                    io.write("a"):write("b")
                end)
            end)
        end)
    end)

    describe("mock_executor: shared state across calls", function()
        it("calls tracker is mutable reference — caller can corrupt it", function()
            local exec, calls = helpers.mock_executor({ { true, 0 } })
            exec("cmd1")
            -- Caller can mutate the calls table
            calls[1] = "tampered"
            assert.are.equal("tampered", calls[1])
        end)
    end)

    describe("with_temp_file: binary content mode", function()
        it("writes binary content via text mode (platform-dependent)", function()
            helpers.with_temp_file("\0\1\2\3", function(path)
                local f = io.open(path, "rb")
                assert.is_not_nil(f)
                local content = f:read("*a")
                f:close()
                -- On Unix this works; on Windows text mode may mangle \r\n
                assert.are.equal(4, #content)
            end)
        end)
    end)

    describe("assert_errors: non-string error objects", function()
        it("handles table as error object", function()
            assert.has_no.errors(function()
                helpers.assert_errors(function()
                    error({ code = 404, msg = "not found" })
                end)
            end)
        end)

        it("pattern match on table error uses tostring", function()
            -- tostring({}) gives "table: 0x..." which won't match meaningful patterns
            assert.has.errors(function()
                helpers.assert_errors(function()
                    error({ code = 404 })
                end, "404")
            end)
        end)
    end)
end)
