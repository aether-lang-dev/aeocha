# Aeocha TODO

## Refinement / Future work

3a. **[DONE — ae 0.328+]** Ambient `fw` (dropped from matchers). `init()` stashes
the framework in a module-level `current_fw` cell; every `assert_*`/`expect_*`/`fail`
and the fluent chain read it, so matchers lost their `fw` parameter
(`aeocha.assert_eq(a, b, msg)`). Only structural calls keep `fw`: top-level
`describe(fw, name)` (no enclosing block to auto-inject `_ctx`) and `run_summary(fw)`.
Hard breaking change (Aether has no overloading, so no gradual path): all 30 matcher
signatures + 47 internal `fail()` call sites + the self-test + both integration probes
+ both regression tests updated. Tradeoff realised: **one framework per process** — a
second `init()` rebinds `current_fw`; the old fw-threaded multi-framework mode is gone.
Suite green on 0.329.

3b. **Consider taking Aeocha back to the Aether repo and bundling.** Aeocha is a single self-contained file (`aeocha.ae`) with no `contrib` deps, no raw externs, and only `std.*` imports — a plain assertion test builds to a libc-only binary (verified via `ldd`). That makes it a natural candidate to live in-tree (e.g. `contrib/aeocha/` again) and ship with the compiler so downstream Aether projects get it without copying the file onto their include path. Tradeoff: independent release cadence + the "no upward deps in tests" boundary are easier to keep when it's a standalone repo; bundling couples Aeocha's version to the compiler's. Decide which matters more before moving.

3c. **[DONE — ae 0.328]** Fluent assertion facade. Subject-first, chainable,
alongside the flat matchers: `expect_int(x).to_equal(5).to_be_gt(0)`,
`expect_str(name).to_contain("foo")`, `expect_int(x).not_().to_equal(5)`. Each
`expect_*` returns a small subject record (value + negated flag); `.to_*` reads it
and reports via `fail` against the ambient `current_fw` cell. Shipped in
`aeocha.ae`; covered in example_self_test.ae; fail paths verified out-of-suite.

  History (both blockers cleared upstream):
  - Cross-module UFCS — fixed 0.327 (aether #934).
  - Module-`var` shared across imports — fixed 0.328 (aether #937). Until this, the
    ambient `current_fw` read back null in a consumer; this (not UFCS) is what sank
    the facade on 0.325/0.327, and re-explains the 0.325 segfault.
  Footgun that cost real time: a missing `exports (...)` line makes a module's UFCS
  methods invisible cross-module (cascades as "Undefined function 'x.foo'"); and the
  happy path never reads `current_fw`, so STALE-CACHE happy-green ghosts masked a
  broken ambient cell. Always `rm -rf ~/.aether/cache` and test a FAIL path.

  Still open: combine with 4f for `within(5s).expect(resp).status(200)`; add a
  string `not_()` and `expect_ptr` if downstream tests want them.

## Timing & Duration (leveraging the first-class `Duration` type)

Aether has a first-class `Duration` type (issue #524): literals with unit
suffixes (`10ns`, `50ms`, `2s`, `1h15m`), stored as `int64` ns, with
`.ns`/`.ms`/`.s` accessors and `dur <op> dur -> bool` comparisons. Comparing a
`Duration` against a plain number is a deliberate type error. These items use it.

Implementation notes (verified on ae 0.325.0):
- `os.now_monotonic_ns()` returns a plain `long` (NTP-jump-free), NOT a `Duration`.
  Keep internal elapsed as plain ns; compare against `budget.ns`.
- `${duration}` interpolation works (largest readable unit: `50ms`, `1.5s`) —
  **fixed upstream, aether #927 CLOSED.** The earlier "format via `.ms`, never
  `${dur}`" workaround is no longer needed and has been removed from the code.
- **Module-scope `var x = 0` infers 32-bit `int`** and a 64-bit RHS now errors with
  `E0200` (was a *silent* truncation) — **fixed upstream, aether #929 CLOSED.** Still
  declare ns-valued cells `var x: long = 0`; the difference is the compiler now tells
  you instead of corrupting silently. Distinct from the `ref_get` truncation note in
  LLM.md — that's a `ref` cell, this is a `var`.
- **Method-call-on-value / UFCS works** (`x.f()` desugars to `f(x)`; chains like
  `expect(5).to_equal(5).to_equal(6)` compile and run) — **landed upstream, aether
  #928 CLOSED.** This is the substrate for a fluent assertion facade (see 3a/4f).

4a. **[DONE] ns-native per-`it()` timing on the monotonic clock.** Switch the
per-`it()` duration from wall-clock `clock_ns()` deltas (can jump under NTP) to
`os.now_monotonic_ns()`. Keep ns internally; the aeb report still emits ms.

4b. **[DONE] Timing-budget matchers.** `expect_elapsed_under(fw, elapsed_ns,
budget: Duration, msg)` — assert a measured span is under a budget written as a
duration literal (`50ms`). Caller measures with `os.now_monotonic_ns()` deltas.

4c. **`it_within(fw, name, budget: Duration) callback { ... }`** — an `it()` that
auto-fails if the test body runs longer than `budget`. Wraps the existing per-`it()`
timing; no manual start/stop in the test body. The ergonomic headline feature.

4d. **`eventually(fw, within: Duration, poll: Duration) callback { ... }`** —
retry-until-pass: re-run the block until its assertions hold or `within` elapses,
sleeping `poll` between attempts. Turns flaky async waits (the HTTP fixture's bare
`sleep(500)`) into a bounded, self-documenting poll loop.

4e. **ns-native aeb report.** Carry full ns resolution through `_build_rows` /
`_format_aeb_report` instead of flattening to ms early, and format (`µs`/`ms`/`s`)
only at the print boundary — fast tests currently all round to `0` ms.

4f. **[DONE — ae 0.328]** `within(budget)` / `without(budget)` — the "floating
modifier" pattern, shipped. `within(5s)` sets an ambient budget the next
`expect_http_get_*` matcher polls against (poll-until-pass); `without(5s)` is
poll-until-absent; `within_poll`/`without_poll` set the interval. One-shot and
auto-reverting; no budget → single-shot as before. Implemented via module-`var`
budget cells + an internal silent probe (`_http_get_probe`) the retry driver loops
— the public matchers never expose the loop. Verified end-to-end: `within(5s)`
waits for a late-binding HTTP server with NO pre-sleep (✓), a one-shot GET to a
dead port fails fast, and `within(800ms)` polls the full budget (~805ms) then
fails. The probe's HTTP section now uses `within(5s)` for readiness instead of the
old `sleep(500)` magic number. Gives `within(5s).expect_http_get_status(...)` — the
FluentSelenium combo.

  Scope note: retry is baked into the GET matchers, NOT a generic
  `eventually(predicate)`. Passing a bare top-level `fn` predicate is needed for the
  generic form, and it's been a moving target:
    - across a module boundary — broken on 0.328 (aether #940); **FIXED in 0.329**.
    - but from INSIDE an `it()` closure — STILL broken on 0.329 (the closure-body
      `_aether_bare_adapter_X undeclared` analogue; filed aether **#943**). Since
      matchers run inside `it()` callbacks, this is the case that matters, so a
      generic `eventually(fw, predicate, msg)` is still blocked. Revisit when #943
      lands; the design is trivial (poll `call(pred)` under the ambient budget — the
      0/1/0 contract is already proven, just can't take a closure-passed predicate).

  DESIGN HISTORY (the "floating modifier" pattern) —
  from FluentSelenium (Paul's own lib): `within(5s)` floats in front of the *next*
matcher, makes that one operation poll-until-pass, then evaporates — "if you don't
do `within` there is no waiting; it doesn't last beyond the operation to its
right." `without(5s)` is the inverse (poll-until-absent). We call it a *floating
modifier* because the scope is positional, not lexical: it isn't a block and binds
no name — it attaches to the next operation like an adverb to a verb (`within(5s)
expect(...)` reads as "patiently, assert ..."), modifies that one op, and reverts.
One-shot + auto-reverting is what distinguishes it from a persistent thread-local.
This is the per-matcher, in-line alternative to 4d's block form, and the more
idiomatic-BDD shape. (Implementation term: the ambient cell described below.)

  PROTOTYPED & VERIFIED (ae 0.324.0, flat-call form, no method-chaining needed):
  a module-static `var retry_budget_ns: long` set by `within(2s)` and read by the
  next matcher gives exactly the 0/1/0 contract (no-within fails fast → within
  retries across a value-flip → budget reverts so the next call fails fast again).

  KEY INSIGHT: this ambient-cell is the SAME substrate as 3a (kill `fw` threading
  via a module-static "current framework"). `fw` and the retry-budget are two
  payloads on one mechanism. So 4f is the natural first consumer of 3a's ambient
  cell, and FluentSelenium is the existence proof that the "dodgy thread-local"
  approach is ergonomically worth it for a single-threaded-per-case test DSL.
  Sequence: 3a (ambient `fw`) → 4f (`within`/`without` on the same substrate) →
  fluent chaining (now unblocked — #928 method-call-on-value landed in 0.325.0, so
  `expect(x).to_equal(5)` and `within(5s).expect(resp).status(200)` are buildable
  once `fw` is ambient). See the new 3c for the fluent-facade item itself.

## Pending Migrations

Once Aeocha is importable + bare-callable, migrate the existing hand-rolled `exit(1)` test files to it:

- `contrib/tinyweb/test_integration.ae`
- `contrib/tinyweb/test_inventory.ae`
- `contrib/tinyweb/test_spec.ae`
- `tests/integration/sqlite_roundtrip/probe.ae`

Each migration gets `describe`/`it` grouping, proper pass/fail counts, and shared before/after hooks.
