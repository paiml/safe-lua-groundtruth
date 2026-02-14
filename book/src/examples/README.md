# Examples Overview

This section contains runnable examples demonstrating safe-lua patterns in real-world scenarios. Each example is a standalone Lua script in the `examples/` directory.

## Running Examples

All examples can be run individually:

```bash
lua5.1 examples/<name>.lua
```

Or run the full suite:

```bash
make examples
```

## Example Index

| Example | Description | Key Modules |
|---------|-------------|-------------|
| [CLI Tool](cli_tool.md) | Safe command-line tool | guard, validate, shell, log |
| [Performance Profiling](profiling.md) | Safe vs unsafe benchmarks | perf, validate, log |
| [Structured Logging](logging.md) | Level gating, child loggers, JSON output | log, guard, validate |
| [PMAT Compliance](compliance.md) | CB-600 compliance matrix | guard, validate, shell, perf, log |
| [Coroutine Parallelization](parallel.md) | Cooperative job scheduler | guard, validate, log |
| [Shell Orchestration](orchestrate.md) | Multi-stage pipeline runner | shell, log, guard, validate |
| [Mutation Testing](mutate.md) | Mutation testing harness | log, validate, guard |
| [OBS Studio Scripting](obs_script.md) | OBS Lua script template | guard, validate, log |
| [Media Pipeline](media_pipeline.md) | FFmpeg/ImageMagick pipeline | shell, guard, validate, log |
| [Config Loading](config_loader.md) | Schema validation and frozen configs | validate, guard, log |
| [File I/O](file_io.md) | Safe read/write/existence/cleanup | guard, validate, log, test_helpers |
| [State Machine](state_machine.md) | Phase lifecycle with timing | guard, validate, log |
| [Testing Patterns](testing_patterns.md) | Mocks, spies, dependency injection | guard, shell, log, test_helpers |
| [String Processing](string_processing.md) | Patterns, gsub, Levenshtein | guard, validate, log, perf |

## Conventions

All examples follow these conventions:

- Shebang: `#!/usr/bin/env lua5.1`
- Package path setup: `package.path = "lib/?.lua;" .. package.path`
- Local-cached stdlib functions at module top
- Main function pattern: `local function main(args) ... return 0 end` + `os.exit(main(arg))`
- Zero luacheck warnings, zero selene errors
