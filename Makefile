LUA ?= lua5.1
BUSTED ?= $(HOME)/.luarocks/bin/busted
MDBOOK ?= $(HOME)/.cargo/bin/mdbook
COVERAGE_MIN ?= 95

.PHONY: test lint fmt fmt-check coverage check bench examples reproduce clean book book-serve

test:
	$(BUSTED) spec/

lint:
	luacheck lib/ spec/ tools/ examples/
	selene lib/
	cd spec && selene .
	cd examples && selene .

fmt:
	stylua lib/ spec/ tools/ benchmarks/ examples/

fmt-check:
	stylua --check lib/ spec/ tools/ benchmarks/ examples/

coverage:
	$(BUSTED) --coverage spec/
	luacov
	$(LUA) tools/check_coverage.lua $(COVERAGE_MIN)

check: lint fmt-check test

bench:
	$(LUA) benchmarks/perf_bench.lua

examples:
	$(LUA) examples/cli_tool.lua --help
	$(LUA) examples/cli_tool.lua search "require" lib/safe/
	$(LUA) examples/profiling.lua 100
	$(LUA) examples/logging.lua
	$(LUA) examples/compliance.lua
	$(LUA) examples/parallel.lua
	$(LUA) examples/orchestrate.lua
	$(LUA) examples/mutate.lua
	$(LUA) examples/obs_script.lua
	$(LUA) examples/media_pipeline.lua
	$(LUA) examples/config_loader.lua
	$(LUA) examples/file_io.lua
	$(LUA) examples/state_machine.lua
	$(LUA) examples/testing_patterns.lua
	$(LUA) examples/string_processing.lua
	$(LUA) examples/oop_patterns.lua
	$(LUA) examples/error_handling.lua
	$(LUA) examples/weak_tables.lua
	$(LUA) examples/coroutine_patterns.lua
	$(LUA) examples/global_protection.lua
	$(LUA) examples/string_building.lua
	$(LUA) examples/type_annotations.lua
	$(LUA) examples/require_safety.lua
	$(LUA) examples/operator_overloading.lua
	$(LUA) examples/table_operations.lua
	$(LUA) examples/observer_pattern.lua
	$(LUA) examples/proxy_tables.lua
	$(LUA) examples/closure_patterns.lua
	$(LUA) examples/data_structures.lua
	$(LUA) examples/serialization.lua
	$(LUA) examples/debug_introspection.lua
	$(LUA) examples/vararg_patterns.lua
	$(LUA) examples/module_patterns.lua

reproduce: clean check coverage

clean:
	rm -f luacov.stats.out luacov.report.out

book:
	$(MDBOOK) build book/

book-serve:
	$(MDBOOK) serve book/ --open
