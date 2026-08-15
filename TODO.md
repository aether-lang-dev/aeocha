# Aeocha TODO

> **Post-thinning note (2026-08-14, updated 2026-08-15):** stage 3 of
> `deprecation_notice.md` is executed and then some — `aeocha.ae` is a
> pure-forwarder facade over `std.spec`, `std.os.testing`, and
> `std.http.client.httptest`; the aeb IPC report is retired (env-file
> transport, aether 0.539 contract); and mutation testing moved upstream
> as `std.mutation` (aether 0.540.0). NOTHING in this file is actionable
> here anymore — feature items belong against aether's std tree; the
> repo's only remaining work is the downstream `import aeocha`
> migrations, after which it archives. This file is a historical record.

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

3b. **[RESOLVED — the std port]** Consider taking Aeocha back to the Aether repo
and bundling. This happened, in the stronger form: the framework core and all
matcher families were ported into the stdlib itself (`std.spec`,
`std.os.testing`, `std.http.client.httptest` — aether PR #1574; mutation
testing followed as `std.mutation` in 0.540.0), not as a bundled
`contrib/aeocha`. This repo remains only as the compatibility facade
(see deprecation_notice.md).

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

  Still open — but now against `std/spec/module.ae`, not here: combine with 4f
  for `within(5s).expect(resp).status(200)`; add a string `not_()` and
  `expect_ptr` if downstream tests want them. The optional-why-message ask
  moved upstream as aether#1576.

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

4c. **[DONE]** `it_within(name, budget: Duration) callback { ... }` — an `it()`
that also fails if the test body runs longer than `budget` (no `fw`, post-3a). It
and plain `it()` share an internal `_it_impl(_ctx, desc, fn, budget_ns)`; budget 0
disables the check. The over-budget `fail()` fires while `current_it` is still set,
so it counts against the case and composes with the normal assertion verdict (an
over-budget body that also asserts wrong shows both messages). Reuses the monotonic
elapsed the aeb report already records — no extra measurement. Self-test covers the
pass path; over-budget + over-budget-and-failing verified out-of-suite.

4d. **[DONE — ae 0.329]** `eventually(pred, msg)` — generic poll-until form of the
floating modifier. `pred` is a zero-arg `fn` returning 1/0; under a preceding
`within(budget)` it polls until `pred` holds, under `without(budget)` until it stops
holding, no budget → one evaluation. Shape landed as a *predicate fn* (not a
trailing block) because that's what the bare-fn-into-closure fixes enable: blocked
through 0.328 by #940 (bare fn across module) then #943 (bare fn inside closure),
both now fixed. Reuses the 4f retry cells; fixed a latent bug found while building
it — `_take_retry_budget` only cleared the budget, so a no-`within` matcher after a
`without()` inherited the stale flag and inverted its sense (the GET matchers had
the same latent bug; now all three retry fields reset, and callers snapshot
poll/without *before* taking the budget). Self-test covers the pass path; the
within-timeout / without / one-shot paths verified out-of-suite.

4e. **[DONE]** ns-native aeb report. The it-record now stores the full ns
duration (`duration_ns_str`) instead of pre-rounded ms; the report carries ns
through `_build_rows` (per-row duration column is ns) and adds a `duration_ns=`
header field. Wire-compatible v1: `version=1` and `duration_ms=` are retained so
existing parsers keep working (the row consumer matches STATUS/index/name/message
and ignores the duration value). Proof: a fast run reports `duration_ms=0,
duration_ns=86395` — real precision where it used to round to 0. The IPC probe now
asserts `duration_ns=` is present.

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
      `_aether_bare_adapter_X undeclared` analogue; was filed aether **#943**).
      BOTH #940 and #943 are now FIXED in 0.329, and `eventually(pred, msg)` shipped
      (see 4d above). History kept here for context.

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

## Adjacent tools

6a. **[DONE — since MOVED UPSTREAM as `std.mutation`, aether 0.540.0; `contrib/mutate` and its regression tests are deleted from this repo]** Mutation testing — `contrib/mutate/mutate.ae`. An outer driver
(Aether) that perturbs a SUT one padded-operator at a time, clears the cache, and
classifies each mutant via Aeocha's STRUCTURED report (not just an exit code):
`ae check` (no-compile gate) → `ae build` → run + drain the `version=1` report off
the IPC channel → read `failed=N`. Three-way verdict: killed (`failed>0`), survived
(`failed==0`, a test gap), no-compile (excluded from the score so a non-compiling
mutant can't masquerade as a kill). Core ~6 code operators PLUS string-literal mutators (non-empty -> "", "" ->
sentinel) — and the engine is string-boundary aware, so a padded operator inside a
"..." literal is no longer mutated as code (fixes the old operator-in-string false
mutant). Reports score + survivors.
Example (`contrib/mutate/example/`) is the README's calc CUT → 100%; the README
shows a survivor case (drop `abs(-7)` → `SUB->ADD` survives → 66%). SUT restored
byte-identical (md5-checked).

Compiler bugs found + worked around (aether **#953**): both `ae check` and
`ae build` print an imported module's compile error to stderr but exit 0 (`build`
even links a stale binary). So the no-compile gate greps `ae check`'s stderr for
`error[` rather than trusting exit codes.

Honest Tier-1 limits in the README: text-based (false mutants possible — incl. its
own fixture comments, which must avoid padded operators), slow (cache-clear +
check + build + run per mutant), no equivalent-mutant detection, restores at end
only (Ctrl-C mid-run leaves the SUT mutated — run on a clean tree). A precise
version needs AST-level mutation upstream (`ae mutate` / `ae inspect` with
positions). Regression: `tests/integration/aeocha_mutation/` asserts the exact
score + survivor + byte-identical SUT restore (verified to fail when restore is
broken).

## Matcher ergonomics (Hamcrest / AssertJ inspiration)

5a. **[DONE]** Custom matchers documented + escape hatch. A matcher is just a fn
that calls `fail(msg)` (Tier-1) — now spelled out in README with examples, since
it's a real strength nobody could discover. Added `satisfies(pred, msg)` /
`satisfies_str` (AssertJ-style fluent escape hatch, `fn(value)->1/0`) and exported
`IntSubject`/`StrSubject`.

5b. **[DONE]** Collection matchers — `expect_list_size`, `expect_list_empty`,
`expect_list_has_str` over a `std.list` of strings. Int-list matchers omitted (raw
list stores ptrs; needs a boxing convention) — revisit if a real test needs it.

5c. **[DONE — ae 0.331]** Cross-module fluent extension fully works. A consumer
module adds its own `.to_*` by writing `to_be_even(s: IntSubject, msg) -> IntSubject`
(or the qualified `aeocha.IntSubject`); UFCS resolves it and it chains. The bare
name worked since 0.329; the qualified type-in-signature gap (aether #946) is fixed
in 0.331, so the disambiguation escape hatch exists too. README shows the working
pattern. Nothing left blocked here.

5d. **Hamcrest-style matcher combinators** (`allOf`/`anyOf`/`is(not(...))` as
matcher *values*) — deliberate non-goal for now, and if demand appears the home
is `std/spec/module.ae`. Needs matcher-as-a-value (a struct carrying predicate +
self-description); large design effort, and soft-assert already covers most of
the need (write several `expect_` calls; they all report).

5e. **[PARTIALLY DONE]** More content matchers. Shipped: `assert_str_eq_diff`
(Jest-style — caret under the first differing byte, aligned to a fixed 19-char
value column; ASCII byte index), `expect_list_contains_all` (containsInAnyOrder),
`expect_list_every` (everyItem, vacuous-pass on empty). Still open — against
`std/spec/module.ae` now: `extracting`/map-then-assert (a list-projection
helper), and the caret diff is byte- not codepoint-aware (fine for ASCII test
output; revisit if multibyte values matter).

## Pending Migrations

These are aether-repo files, and with `std.spec` in-tree they should migrate to
`import std.spec` directly (no aeocha dependency needed) — so this item now
belongs in the aether repo's backlog, kept here only until it lands there:

- `contrib/tinyweb/test_integration.ae`
- `contrib/tinyweb/test_inventory.ae`
- `contrib/tinyweb/test_spec.ae`
- `tests/integration/sqlite_roundtrip/probe.ae`

Each migration gets `describe`/`it` grouping, proper pass/fail counts, and shared before/after hooks.
