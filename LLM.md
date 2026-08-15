# Notes to self (LLM assisting on Aeocha)

Not a CLAUDE.md — short, opinionated, written for a future LLM picking up mid-task. Re-read at start of every session.

## Context
Aeocha is a BDD-style test framework for Aether. As of 2026-08-14 it is **thinned** (stage 3 of `deprecation_notice.md`, executed): the framework core and every matcher family were ported verbatim into the Aether stdlib, and `aeocha.ae` is now a ~465-line compatibility facade of thin forwarders. `import aeocha` code keeps working unchanged; the implementations live upstream:

- `std.spec` — framework core (`init`/`describe`/`it`/`it_within`/hooks/`fail`/`run_summary`), flat `assert_*`, fluent chain (`expect_int`/`expect_str`/`to_*`/`not_`/`satisfies*`, `IntSubject`/`StrSubject`), collection matchers, `expect_elapsed_under`. Also the ambient `current_fw` cell.
- `std.os.testing` — process matchers (`expect_exit`, `expect_no_spawn_error`, `expect_stdout_*`, `expect_stderr_*`).
- `std.http.client.httptest` — HTTP matchers (low-level `expect_http_*` on a resp, high-level GET/POST-and-assert), `within`/`within_poll`/`without`/`without_poll`, `eventually`, and the one-shot retry cells. (Named `httptest` per Go, because two co-imported modules can't share a namespace tail.)

Behavioral principles for those surfaces (matcher semantics, retry gotchas, monotonic-clock rules, glob-vs-regex, stdout-vs-stderr slots) are documented in the std modules themselves and aether's docs/testing.md — maintain them THERE, not here.

## What still lives in this repo — and must not be deleted
1. **Mutation testing** (`contrib/mutate/`) — source-rewriting tool, not a library surface. Its oracle reads the `version=1` report via the env-file transport: it runs each mutant's test binary with `AE_SPEC_FORMAT=aeocha AE_SPEC_REPORT=<bin>.report` set and parses `failed=N` from the file. Tests: `tests/integration/aeocha_mutation/`.
2. **The Cucumber plan** (`cucumber-plan.md`) — unbuilt design proposal.

**The aeb IPC back-channel is RETIRED** (2026-08-15). The `version=1` format lives on as a documented, versioned contract in aether docs/testing.md (0.539), produced by `spec._format_aeocha_v1` via the `AE_SPEC_FORMAT`/`AE_SPEC_REPORT` env pair; aeb's `driver_test` consumes it that way since aeb 009c830. `run_summary` here is now a pure forwarder — old aeb versions that only drained the IPC pipe fall back to exit-code granularity, which is their documented no-report path.

## Forwarder rules (why the facade is shaped the way it is)
- **Whole-module imports + namespaced calls** (`import std.spec` … `spec.fail(msg)`), NOT selective imports: selectively importing a fn that reads its module's mutable var fails to pull the global (aether #1573) — `fail` and the retry family are exactly that shape.
- **Type re-export works**: `aeocha.ae` re-exports `IntSubject`/`StrSubject` (std.spec's structs) via `exports(...)` after a whole-module import; consumers can still name them in type positions and add their own `.to_*` via UFCS (verified end-to-end).
- The ambient cells (spec's `current_fw`, httptest's retry budget) are shared module vars, so mixing `aeocha.*` and `spec.*`/`httptest.*` calls in one process stays coherent — all three std arms report through `spec.fail`.
- `fn`-typed and `Duration`-typed params forward cleanly through the shims (probed; #940/#943 territory is fine).

## Building / Testing
- **Git workflow**: Paul and Nic push directly to `main` — no PR, no feature branch. Commit on `main` and push. (Only branch if explicitly asked.)
- **Compiler**: needs an `ae` whose stdlib HAS the three modules — **aether 0.538.0+** (PR #1574, released 2026-08-14; pinned in README). Older toolchains *silently tolerate* `import std.spec` but every `spec.*` call fails as undefined — don't be fooled by a passing bare-import probe. A branch-parity build also lives at `/home/paul/scm/aether/build/ae` if the installed `ae` is older.
- **Module resolution / include path**: `ae` resolves a bare `import aeocha` from the cwd or from `AETHER_LIB_DIR` / `--lib` (PATH-style). It does NOT walk up from the source file, and `AETHER_INCLUDE_PATH` is not a real variable. `std.*` imports resolve from the toolchain, not from lib dirs — pointing `AETHER_LIB_DIR` at an aether checkout does not get you its stdlib.
- **STALE CACHE — bites hard**: `~/.aether/cache` does NOT invalidate when an imported module's source changes. After editing `aeocha.ae` (or switching toolchains), `rm -rf ~/.aether/cache` or you will debug a ghost. And always test a FAIL path — the happy path never exercises the ambient `current_fw` cell, so a broken cell shows all-green.
- **Integration tests**: `./tests/integration/*/test_*.sh` (they take `ae` from PATH — prepend `/home/paul/scm/aether/build` until the release lands). The `aeocha_mutation` ones run `contrib/mutate` against deterministic fixtures (expects `1/2 … 50%`, MUL->DIV survivor, md5-identical restore); the fixture comments avoid padded operators on purpose — keep operator tokens out of their prose.
- **Bootstrap**: `./bootstrap_aether.sh` for contributors with no suitable `ae`: release-first fallback, caches toolchains under `.aether/toolchains/`, prints the PATH export. `AETHER_VERSION` pins; `AEOCHA_AETHER_SOURCE=1` forces source build.

## Files/dirs worth knowing
- `aeocha.ae`: the facade — pure forwarders, nothing else.
- `deprecation_notice.md`: what moved where, and why the keeps are keeps.
- `tests/integration/`: expect-matchers smoke, mutation regression (which also exercises the env-file report path).
- `tests/regression/`: compiler-feature regressions Aeocha exercises.
- `example_self_test.ae`: how to use the framework; also the facade's broadest test.
- `asks/archive/`: delivered/relocated asks (the fluent why-message ask became aether#1576).

## Idioms that keep biting
- **Trailing Blocks**: use the trailing block pattern for `describe`; nested calls auto-inject the suite `_ctx`, top-level `describe(fw, …)` and `run_summary(fw)` still take `fw` explicitly.
- **Detached server hangs the process**: a test spinning up an in-process `std.http` server runs it on a detached actor thread that never returns; `run_summary` only `exit(1)`s on failure, so on success the process hangs holding its port. End `main()` with an explicit `exit(0)`.
- **No upward deps in tests**: Aeocha sits at the bottom of the stack — its tests must not depend on downstream projects (no `servirtium-vcr`; hand-rolled `std.http` fixture servers only).
