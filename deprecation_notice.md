# Deprecation notice: most of aeocha.ae now lives in the Aether stdlib

Status: written 2026-08-15, as the aether branch
`claude/integrate-aeocha-assertions-taq64v` (std.spec + the two matcher
arms) heads to PR. Everything in the "remove" list below exists in that
branch as a verbatim port; aeocha's copies are now duplicates that will
drift. This note says what to delete from `aeocha.ae`, what MUST stay
because it has no stdlib home yet, and the order to do it in.

## Where things went

| aeocha surface | new home | import |
|---|---|---|
| `init`, `describe`, `it`, `it_within`, `before_each`, `after_each`, `fail`, the `assert_*` family, `run_summary` | `std/spec/module.ae` | `import std.spec` |
| Fluent chain: `expect_int`, `expect_str`, `not_`, `satisfies`, `satisfies_str`, `IntSubject`, `StrSubject` | `std/spec/module.ae` | `import std.spec` |
| Collection matchers: `expect_list_*` (5) | `std/spec/module.ae` | `import std.spec` |
| Timing: `expect_elapsed_under` | `std/spec/module.ae` | `import std.spec` |
| Process matchers: `expect_exit`, `expect_no_spawn_error`, `expect_stdout_*` (6), `expect_stderr_*` (2) | `std/os/testing/module.ae` | `import std.os.testing` |
| HTTP matchers: `expect_http_*` (11), `within` / `within_poll` / `without` / `without_poll`, `eventually`, `_take_retry_budget` + the retry cells | `std/http/client/httptest/module.ae` | `import std.http.client.httptest` |

(`httptest`, not `testing`: Aether import aliasing parses but does not
resolve yet, so two co-imported modules cannot share a namespace tail.
Name chosen per Go's `net/http/httptest`.)

## KEEP — no stdlib home yet

1. **The aeb IPC reporting back-channel.** `run_summary`'s
   `ipc.parent_channel()` branch, `_format_aeb_report`, `_build_rows`,
   and the 60 KB fallback tiers (full → no-msg → minimal → header-only).
   The pinned `version=1` KV+tab format is aeb `driver_test`'s contract
   (see aeocha-aeb-ipc-reporting.md). std.spec deliberately grew a
   DIFFERENT transport for `ae test --format` (env-file via
   `AE_SPEC_FORMAT` / `AE_SPEC_REPORT`); the IPC one stays here until
   someone converges the two. Removing it breaks `aeb test`.

2. **Mutation testing** (`contrib/mutate/`). A source-rewriting tool,
   not a library surface. If it ever moves to aether it becomes an
   `ae mutate` subcommand — different discussion entirely.

3. **The Cucumber plan** (`cucumber-plan.md`) — unbuilt design
   proposal; nothing to port.

4. **`bootstrap_aether.sh`, docs/, LLM.md, the test suites** — repo
   infrastructure. `tests/integration/aeocha_aeb_ipc_reporting` is the
   only test of KEEP-item 1; it must survive any thinning.

## REMOVE — but in this order (stage 3, "thinning")

Do NOT delete the duplicated bodies outright: `import aeocha` users
(and this repo's own tests) call `aeocha.assert_eq(...)` etc. The
compat-preserving shape is re-export shims:

1. Replace each duplicated function body in `aeocha.ae` with a thin
   forwarder to the std module (`assert_eq(a, e, m) {
   spec.assert_eq(a, e, m) }` — whole-module imports + namespaced
   calls, NOT selective imports: aether #1573, selectively importing a
   function that reads its module's mutable var fails to pull the
   global, and `fail`/the retry family are exactly that shape).
2. `run_summary` becomes: forward to `spec.run_summary(fw)` for the
   counters/exit, then run the KEEP-1 IPC block against the same fw.
   CAUTION: the ambient `current_fw` cell then lives in std.spec, not
   here — `init()` must forward to `spec.init()` and the IPC block must
   read counters through fw (which it already does), never through a
   local cell.
3. The fluent-chain structs (`IntSubject`/`StrSubject`) cannot be
   forwarded as opaque re-exports if callers name the types — check
   whether any consumer does before thinning those; worst case they
   stay as duplicates until aether grows type re-export.
4. Only after aeocha's own suites pass against the shims, delete the
   dead private helpers the forwarders orphaned.

Precondition for all of it: the aether branch above actually merged
and released — pin the minimum aether version in README when thinning.

## Housekeeping while you're here

- `asks/http-get-and-assert-matchers.md` and
  `asks/http-post-and-assert-matchers.md` are DELIVERED (the matchers
  shipped, now in std too) — close/archive them.
- `asks/fluent-matchers-optional-why-message.md` is still open, but the
  right target is now `std/spec/module.ae`, not this repo — move the
  ask to an aether issue.
- TODO.md item 3a is done and says so; several other items now belong
  against std.spec — sweep them the same way.
