Iy Notes to self (LLM assisting on Aeocha)

Not a CLAUDE.md — short, opinionated, written for a future LLM picking up mid-task. Re-read at start of every session.

## Context
Aeocha is a BDD-style test framework for Aether, featuring `describe`, `it`, `before_each`, and `after_each` syntax. It's the primary test framework for Aether projects.

## Development Principles
- **BDD Syntax**: Follow the `describe` and `it` pattern.
- **Framework Context**: The `fw` context is threaded through most calls because Aether rejects mutable module-level identifiers.
- **Integration Matchers**: Maintain the `expect_*` matchers for process and HTTP testing. These are designed to be high-level and reduce boilerplate in integration tests. Two HTTP layers exist: *low-level* (`expect_http_status`, `expect_http_body_eq`, `expect_http_body_contains`, `expect_http_header`, `expect_http_body_json_field`) take a `resp` the caller builds/frees; *high-level* (`expect_http_get_status`, `expect_http_get_body_eq`, `expect_http_get_body_contains`) do the GET + request/free lifecycle themselves so a test asserts a response in one line. The high-level ones reuse the low-level ones internally. Note `send_request` already frees `resp` and returns null on transport error — the error branch must NOT `response_free`.
- **IPC Reporting**: `run_summary` emits a structured v1 report if it detects a parent IPC channel (e.g., when run by `aeb`).

## Building / Testing
- **Compiler**: Uses system-wide `ae` (v0.161.0+ — `std.strbuilder` v2 in `_build_rows`, `string.char_at_n` in the stdout matchers; ≥0.157.0 is the hard floor for leak-clean heap-accumulator returns).
- **Include Path**: When testing locally, set `AETHER_INCLUDE_PATH` to the repo root to use the local `aeocha.ae`.
- **STALE CACHE — bites hard**: `~/.aether/cache` does NOT invalidate when an imported module's source changes. After editing `aeocha.ae`, the next `ae run` of any test silently keeps running the *previously compiled* `aeocha` — edits, even syntax errors, are ignored. Always `rm -rf ~/.aether/cache` after touching `aeocha.ae`, or you will debug a ghost.
- **Integration Tests**: Run `./tests/integration/aeocha_aeb_ipc_reporting/test_aeocha_aeb_ipc_reporting.sh` etc.
- **Bootstrap**: Use `./bootstrap_aether.sh` to fetch and build Aether locally if not installed.

## Files/dirs worth knowing
- `aeocha.ae`: The core framework implementation and Aether-facing surface.
- `tests/integration/`: Integration tests that exercise process and HTTP matchers.
- `tests/regression/`: Regression tests for compiler features that Aeocha exercises.
- `example_self_test.ae`: A good starting point for seeing how to use the framework.

## Idioms that keep biting
- **Trailing Blocks**: Use the trailing block pattern for `describe`.
- **Closure Capturing**: Be mindful of closure capturing rules in Aether when using hooks.

