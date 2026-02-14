LUA ?= lua5.1
BUSTED ?= $(HOME)/.luarocks/bin/busted
MDBOOK ?= $(HOME)/.cargo/bin/mdbook
COVERAGE_MIN ?= 95

.PHONY: test lint fmt fmt-check coverage check bench reproduce clean book book-serve

test:
	$(BUSTED) spec/

lint:
	luacheck lib/ spec/ tools/
	selene lib/
	cd spec && selene .

fmt:
	stylua lib/ spec/ tools/ benchmarks/

fmt-check:
	stylua --check lib/ spec/ tools/ benchmarks/

coverage:
	$(BUSTED) --coverage spec/
	luacov
	$(LUA) tools/check_coverage.lua $(COVERAGE_MIN)

check: lint fmt-check test

bench:
	$(LUA) benchmarks/perf_bench.lua

reproduce: clean check coverage

clean:
	rm -f luacov.stats.out luacov.report.out

book:
	$(MDBOOK) build book/

book-serve:
	$(MDBOOK) serve book/ --open
