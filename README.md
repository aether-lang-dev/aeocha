# Aeocha — sunset. Use the Aether stdlib.

Aeocha's entire surface was ported verbatim into the
[Aether](https://github.com/aether-lang-dev/aether) stdlib during
2026-08-14/15, and this repo no longer ships any code — not even the
compatibility facade. `import aeocha` does not resolve anymore; do the
migration below. The full story is in
[deprecation_notice.md](deprecation_notice.md); everything else lives in git
history.

## Where everything went

| Was | Now | Since |
|---|---|---|
| Framework core, flat `assert_*`, fluent chain, collection + timing matchers | `import std.spec` | aether 0.538.0 |
| Process matchers (`expect_exit`, `expect_stdout_*`, `expect_stderr_*`) | `import std.os.testing` | aether 0.538.0 |
| HTTP matchers, `within`/`without`, `eventually` | `import std.http.client.httptest` | aether 0.538.0 |
| Structured `version=1` test reports (the aeb contract) | `AE_SPEC_FORMAT=aeocha` + `AE_SPEC_REPORT=<path>` env pair, written by `spec.run_summary` (documented contract: aether docs/testing.md) | aether 0.539.0 |
| Mutation testing (`contrib/mutate`) | `import std.mutation` (`mutation.run(sut, test, lib_dir)`; runnable front-end in aether `examples/mutation-testing/`) | aether 0.540.0 |
| Cucumber acceptance-framework design proposal | aether `asks/cucumber-style-acceptance-framework.md` | — |

Bonus for migrating: aether 0.542.0 gave the fluent value matchers an optional
trailing why-message (`spec.expect_int(n).to_be_gt(0, "derived budget is never
zero")`) — a feature the facade never had.

## Migration recipe

Toolchain floor: **aether ≥ 0.538.0** (0.540.0+ if you use mutation testing,
0.542.0+ for the fluent why-message).

1. Replace `import aeocha` with whichever of the three modules the file
   actually uses (most test files need only `std.spec`).
2. Re-namespace calls — **arm-specific renames first, blanket last**:
   - `aeocha.expect_exit`, `aeocha.expect_no_spawn_error`,
     `aeocha.expect_stdout_*`, `aeocha.expect_stderr_*` → `testing.…`
   - `aeocha.within`, `aeocha.within_poll`, `aeocha.without`,
     `aeocha.without_poll`, `aeocha.eventually`, `aeocha.expect_http_*`
     → `httptest.…`
   - everything else (`init`, `describe`, `it`, `it_within`, hooks, `fail`,
     `assert_*`, `expect_elapsed_under`, `expect_int`/`expect_str`/`not_`,
     `satisfies*`, `expect_list_*`, `run_summary`) → `spec.…`
3. Fluent chains need no rename past the starter: `.to_equal(…)`,
   `.to_contain(…)` etc. resolve via UFCS once `std.spec` is imported. Only
   `aeocha.expect_int(…)` → `spec.expect_int(…)`.
4. Type positions: `aeocha.IntSubject` / `aeocha.StrSubject` →
   `spec.IntSubject` / `spec.StrSubject` (bare `IntSubject` keeps working
   under `import std.spec`).
5. Drop any `AETHER_LIB_DIR` / `--lib` entry that pointed at a checkout of
   this repo, and `rm -rf ~/.aether/cache` before the first rebuild.

### If your code says `import contrib.aeocha` (pre-spinout vintage)

You are resolving against orphaned toolchain snapshots
(`$PREFIX/share/aether/contrib/aeocha/`) that no current aether install
creates, and your matcher calls likely still thread `fw` as the first
argument (`aeocha.assert_eq(fw, a, b, msg)` — the pre-0.328 API). Migrate as
above AND drop the `fw` argument from every matcher call; only top-level
`describe(fw, …)` and `run_summary(fw)` keep it. Delete the orphaned
snapshots when done — nothing refreshes them.

## Known consumers at sunset time

aeo (~77 files), aether-ui (~63), avn (~30, on the `contrib.aeocha` path),
fbs-core (~18), aeci (~16), fight_flash_fraud (2). aeb and servirtium-vcr are
already clean.

## License

MIT. See [LICENSE](LICENSE).
