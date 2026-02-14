local shell = require("safe.shell")

describe("safe.shell", function()
    describe("escape", function()
        it("wraps in single quotes", function()
            assert.are.equal("'hello'", shell.escape("hello"))
        end)

        it("escapes embedded single quotes", function()
            assert.are.equal("'it'\\''s'", shell.escape("it's"))
        end)

        it("handles empty string", function()
            assert.are.equal("''", shell.escape(""))
        end)

        it("handles spaces", function()
            assert.are.equal("'hello world'", shell.escape("hello world"))
        end)

        it("handles special characters", function()
            assert.are.equal("'$HOME'", shell.escape("$HOME"))
        end)

        it("converts numbers to string", function()
            assert.are.equal("'42'", shell.escape(42))
        end)
    end)

    describe("escape_args", function()
        it("escapes and joins arguments", function()
            assert.are.equal("'a' 'b' 'c'", shell.escape_args({ "a", "b", "c" }))
        end)

        it("handles empty array", function()
            assert.are.equal("", shell.escape_args({}))
        end)

        it("handles single arg", function()
            assert.are.equal("'hello world'", shell.escape_args({ "hello world" }))
        end)
    end)

    describe("validate_program", function()
        it("accepts simple names", function()
            local ok, err = shell.validate_program("ls")
            assert.is_true(ok)
            assert.is_nil(err)
        end)

        it("accepts paths", function()
            local ok, err = shell.validate_program("/usr/bin/ls")
            assert.is_true(ok)
            assert.is_nil(err)
        end)

        it("rejects semicolons", function()
            local ok, err = shell.validate_program("ls; rm")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)

        it("rejects pipes", function()
            local ok, err = shell.validate_program("ls | grep")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)

        it("rejects backticks", function()
            local ok, err = shell.validate_program("ls`whoami`")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)

        it("rejects dollar signs", function()
            local ok, err = shell.validate_program("$SHELL")
            assert.is_false(ok)
            assert.truthy(err:find("metacharacters"))
        end)

        it("rejects empty string", function()
            local ok, err = shell.validate_program("")
            assert.is_false(ok)
            assert.truthy(err:find("must not be empty"))
        end)

        it("rejects non-string", function()
            local ok, err = shell.validate_program(42)
            assert.is_false(ok)
            assert.truthy(err:find("must be string"))
        end)
    end)

    describe("validate_args", function()
        it("accepts string array", function()
            local ok, err = shell.validate_args({ "a", "b" })
            assert.is_true(ok)
            assert.is_nil(err)
        end)

        it("accepts empty array", function()
            local ok, err = shell.validate_args({})
            assert.is_true(ok)
            assert.is_nil(err)
        end)

        it("rejects non-table", function()
            local ok, err = shell.validate_args("not a table")
            assert.is_false(ok)
            assert.truthy(err:find("must be table"))
        end)

        it("rejects non-string elements", function()
            local ok, err = shell.validate_args({ "a", 42 })
            assert.is_false(ok)
            assert.truthy(err:find("arg%[2%] must be string"))
        end)
    end)

    describe("build_command", function()
        it("builds command with no args", function()
            assert.are.equal("ls", shell.build_command("ls", {}))
        end)

        it("builds command with args", function()
            assert.are.equal("ls '-la' '/tmp'", shell.build_command("ls", { "-la", "/tmp" }))
        end)

        it("errors for invalid program", function()
            assert.has.errors(function()
                shell.build_command("ls; rm", { "-rf" })
            end)
        end)

        it("handles nil args as empty", function()
            assert.are.equal("ls", shell.build_command("ls", nil))
        end)
    end)

    describe("exec", function()
        local orig_executor

        before_each(function()
            orig_executor = shell._executor
        end)

        after_each(function()
            shell._executor = orig_executor
        end)

        it("calls executor with built command", function()
            local called_with = nil
            shell._executor = function(cmd)
                called_with = cmd
                return true, 0
            end
            local ok, code = shell.exec("echo", { "hello" })
            assert.is_true(ok)
            assert.are.equal(0, code)
            assert.are.equal("echo 'hello'", called_with)
        end)

        it("returns failure from executor", function()
            shell._executor = function(_cmd)
                return false, 1
            end
            local ok, code = shell.exec("false", {})
            assert.is_false(ok)
            assert.are.equal(1, code)
        end)

        it("defaults args to empty", function()
            local called_with = nil
            shell._executor = function(cmd)
                called_with = cmd
                return true, 0
            end
            shell.exec("ls")
            assert.are.equal("ls", called_with)
        end)
    end)

    describe("capture", function()
        local orig_popen

        before_each(function()
            orig_popen = shell._popen
        end)

        after_each(function()
            shell._popen = orig_popen
        end)

        it("returns captured output", function()
            shell._popen = function(_cmd)
                return true, "output text\n"
            end
            local ok, output = shell.capture("echo", { "hello" })
            assert.is_true(ok)
            assert.are.equal("output text\n", output)
        end)

        it("returns failure", function()
            shell._popen = function(_cmd)
                return false, nil
            end
            local ok, output = shell.capture("nonexistent", {})
            assert.is_false(ok)
            assert.is_nil(output)
        end)

        it("builds command correctly", function()
            local called_with = nil
            shell._popen = function(cmd)
                called_with = cmd
                return true, ""
            end
            shell.capture("grep", { "-r", "pattern", "/path" })
            assert.are.equal("grep '-r' 'pattern' '/path'", called_with)
        end)

        it("defaults args to empty", function()
            local called_with = nil
            shell._popen = function(cmd)
                called_with = cmd
                return true, ""
            end
            shell.capture("date")
            assert.are.equal("date", called_with)
        end)
    end)

    describe("_normalize_exit", function()
        it("handles Lua 5.1 numeric success (0)", function()
            local ok, code = shell._normalize_exit(0)
            assert.is_true(ok)
            assert.are.equal(0, code)
        end)

        it("handles Lua 5.1 numeric failure", function()
            local ok, code = shell._normalize_exit(1)
            assert.is_false(ok)
            assert.are.equal(1, code)
        end)

        it("handles Lua 5.2+ triple return success", function()
            local ok, code = shell._normalize_exit(true, "exit", 0)
            assert.is_true(ok)
            assert.are.equal(0, code)
        end)

        it("handles Lua 5.2+ triple return failure", function()
            local ok, code = shell._normalize_exit(nil, "exit", 1)
            assert.is_false(ok)
            assert.are.equal(1, code)
        end)

        it("handles boolean true return", function()
            local ok, code = shell._normalize_exit(true)
            assert.is_true(ok)
            assert.are.equal(0, code)
        end)

        it("handles boolean false return", function()
            local ok, code = shell._normalize_exit(false)
            assert.is_false(ok)
            assert.are.equal(1, code)
        end)
    end)

    describe("default executor (real)", function()
        it("runs true successfully", function()
            local ok, _code = shell.exec("true", {})
            assert.is_true(ok)
        end)

        it("runs false with failure", function()
            local ok, _code = shell.exec("false", {})
            assert.is_false(ok)
        end)
    end)

    describe("default popen (real)", function()
        it("captures echo output", function()
            local ok, output = shell.capture("echo", { "hello" })
            assert.is_true(ok)
            assert.truthy(output:find("hello"))
        end)

        it("captures multi-arg output", function()
            local ok, output = shell.capture("printf", { "%s %s", "a", "b" })
            assert.is_true(ok)
            assert.is.truthy(output)
        end)
    end)
end)
