Iy Notes to self (LLM assisting on Aeocha)

Not a CLAUDE.md — short, opinionated, written for a future LLM picking up mid-task. Re-read at start of every session.

## Context
Aeocha is a BDD-style test framework for Aether, featuring `describe`, `it`, `before_each`, and `after_each` syntax. It's the primary test framework for Aether projects.

## Development Principles
- **BDD Syntax**: Follow the `describe` and `it` pattern.
- **Framework Context**: The `fw` context is threaded through most calls because Aether rejects mutable module-level identifiers.
- **Integration Matchers**: Maintain the `expect_*` matchers for process and HTTP testing. These are designed to be high-level and reduce boilerplate in integration tests. Two HTTP layers exist: *low-level* (`expect_http_status`, `expect_http_body_eq`, `expect_http_body_contains`, `expect_http_header`, `expect_http_body_json_field`) take a `resp` the caller builds/frees; *high-level* (`expect_http_get_status`, `expect_http_get_body_eq`, `expect_http_get_body_contains`) do the GET + request/free lifecycle themselves so a test asserts a response in one line. The high-level ones reuse the low-level ones internally. Note `send_request` already frees `resp` and returns null on transport error — the error branch must NOT `response_free`. `expect_http_header` uses the `client.response_header` wrapper (snapshot-safe via `string.copy`, upstream #269), NOT the raw `http_response_header_raw` extern — the raw form aliases a thread-local buffer the next call clobbers.
- **Process matchers — stdout vs stderr**: stdout matchers (`expect_stdout_contains`, `expect_stdout_matches`, etc.) consume `os.run_capture`'s output. For child *stderr*, use `os.run_full(prog, argv, env, stdin) -> (stdout, stderr, exit, err)` (separate-stream capture, no pipe deadlock) and feed its 2nd slot to `expect_stderr_contains` / `expect_stderr_empty`. Don't confuse run_full's `stderr` slot (child fd 2) with `run_capture`'s third slot (spawn-error string, consumed by `expect_no_spawn_error`).
- **Pattern matchers — glob vs regex**: `expect_stdout_matches` is glob-only (`std.string.glob_match`, no extra deps). `expect_stdout_matches_regex` is full PCRE2 via `std.regex` (unanchored, per-line). regex requires `libpcre2-8` at runtime; if absent, every entry returns a clean error via the `(ok, err)` slot — the matcher treats a non-empty `err` as a loud failure (so a missing-lib env fails, not silently passes). Use glob where libpcre2 may be absent.
- **Timing & Duration**: Per-`it()` timing uses `os.now_monotonic_ns()` (NTP-jump-free) for the elapsed delta — NOT `clock_ns()` (wall clock, can step mid-run). `init()` stamps the run-start monotonically too; the aeb-report total must use the same clock or the delta is garbage. `expect_elapsed_under(fw, elapsed_ns, budget: Duration, msg)` takes a plain int64 ns span the caller measures and a `Duration` literal budget (`50ms`). Aether's `Duration` (issue #524) is a distinct type: `Duration`-vs-plain-number is a type error, so bridge via the `.ns` accessor (`elapsed_ns < budget.ns`). `${duration}` interpolation renders the largest readable unit (`50ms`, `1.5s`) — fixed in ae 0.325.0 (was #927). Future timing helpers (`it_within`, `eventually`, `within`/`without`) are in TODO.md §Timing.
- **No upward deps in tests**: Aeocha is the lowest-level test framework in the stack — its own tests must not depend on downstream projects. The HTTP-matcher probe uses a plain in-process `std.http` server (hand-rolled routes), NOT `servirtium-vcr` (VCR moved out of the aether stdlib into the standalone `servirtium-vcr` project, imported as `core.vcr`; don't reintroduce `std.http.server.vcr`).
- **IPC Reporting**: `run_summary` emits a structured v1 report if it detects a parent IPC channel (e.g., when run by `aeb`).

## Building / Testing
- **Compiler**: Uses system-wide `ae`. Developed/verified on **v0.325.0**. Practical floor is the `Duration` type used by `expect_elapsed_under` (`Duration` literals + `.ns` accessor, ~v0.19x) plus `os.run_full` (stderr matchers, v0.231) and `std.regex` (v0.191). 0.325.0 also brings the fixes Aeocha relies on cleanly: `${duration}` interpolation (#927), the module-`var` narrowing guard (#929), and method-call-on-value/UFCS (#928, the substrate for any future fluent facade). Older notes (`std.strbuilder` v2 since v0.161, `string.char_at_n`) still hold but are well below the real floor now.
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
- **Detached server hangs the process**: A test that spins up an in-process `std.http` server runs it on a detached actor thread that never returns. `run_summary` only `exit(1)`s on failure, so on success the process hangs holding its port — next run fails to bind. End `main()` with an explicit `exit(0)`.

