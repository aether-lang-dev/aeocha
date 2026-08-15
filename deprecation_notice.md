# Deprecation notice: most of aeocha.ae now lives in the Aether stdlib

Status: written 2026-08-15, as the aether branch
`claude/integrate-aeocha-assertions-taq64v` (std.spec + the two matcher
arms) heads to PR. Everything in the "remove" list below exists in that
branch as a verbatim port; aeocha's copies are now duplicates that will
drift. This note says what to delete from `aeocha.ae`, what MUST stay
because it has no stdlib home yet, and the order to do it in.

**EMPTIED 2026-08-15**: aether adopted the mutation tester as
`std.mutation` (0.540.0, released) — with the runnable front-end, both
regression fixtures, and docs — and 0.542.0 landed the fluent
why-message (#1576, the last open aeocha-origin ask). `contrib/` and
the mutation tests are deleted here. **This repo is now facade-only**:
`aeocha.ae` (pure forwarders, frozen at the 0.538 surface),
`cucumber-plan.md` (unbuilt proposal), and repo infrastructure.
Archival is gated solely on the downstream `import aeocha` migrations
(aeo, aether-ui, avn — which is on the pre-spinout `contrib.aeocha`
path — fbs-core, aeci, fight_flash_fraud).

**CONVERGED 2026-08-15**: KEEP-item 1 below (the aeb IPC back-channel)
is now RETIRED too. The transports converged the other way — aether
0.539 documents the `AE_SPEC_REPORT` aeocha-v1 format as a versioned
contract, aeb's `driver_test` adopted it (aeb 009c830: sets the env
pair, reads the file when the pipe is empty), and `contrib/mutate`
migrated to the same transport. `run_summary` is a pure forwarder;
`_format_aeb_report`/`_build_rows` and the
`aeocha_aeb_ipc_reporting` test are deleted. `aeocha.ae` is 100%
forwarders (~357 lines); only `contrib/mutate` remains as real code in
this repo.

**EXECUTED 2026-08-14**: stage 3 below is done — `aeocha.ae` is the
forwarder facade (1667 → ~465 lines), all suites green against the
branch-built toolchain (`/home/paul/scm/aether/build/ae`), asks/TODO
swept (the fluent why-message ask became aether#1576). The precondition
cleared the same night: PR #1574 merged and released as aether
**0.538.0** (2026-08-14), now pinned in the README. Note the type
re-export worry in item 3 turned out moot: re-exporting spec's
`IntSubject`/`StrSubject` through `exports(...)` works, including
consumers naming them in type positions.

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
   *(Update 2026-08-15: RESOLVED — the ask was filed and aether adopted
   it the same day as `std.mutation` (0.540.0): `mutation.run(sut, test,
   lib_dir)`, a runnable front-end at `examples/mutation-testing/`, the
   two regression fixtures at `tests/integration/mutation_testing/`, and
   docs/mutation-testing.md. `contrib/mutate` and its tests are deleted
   here. The repo is now facade-only — archival is gated solely on the
   downstream `import aeocha` migrations.)*

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
