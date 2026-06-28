# Aeocha

A BDD-style test framework for Aether, featuring `describe`, `it`, `before_each`, and `after_each` syntax with trailing blocks and closures.

Inspired by [Cuppa](https://cuppa.forgerock.org).

## Installation

```bash
# Clone the repository
git clone https://github.com/aether-lang-org/aeocha.git
cd aeocha

# Use the bootstrap script to set up the Aether toolchain
./bootstrap_aether.sh
```

## Quick Start

```aether
import aeocha (*)

main() {
    fw = init()

    describe(fw, "Math") {
        it(fw, "adds correctly") callback {
            assert_eq(fw, 1 + 1, 2, "math")
        }
    }

    run_summary(fw)
}
```

Run with `ae run my_test.ae`. Exit code `0` on success, `1` on failure.

## Features

- **BDD Syntax**: Clean, nested `describe` and `it` blocks.
- **Hooks**: Supports `before_each` and `after_each` for setup/teardown.
- **Assertions**: Robust set of integer, string, and pointer matchers.
- **Integration Testing**: Specialized matchers for process output, exit codes, and HTTP responses.
- **Tooling Ready**: Compatible with Aether's `aeb` test runners.

## API Reference

| Function | Purpose |
|----------|---------|
| `init()` | Initialize framework context. |
| `describe(fw, name) { … }` | Group tests. |
| `it(name) callback { … }` | Define a test case. |
| `it_within(name, budget) callback { … }` | A test case that also fails if its body runs longer than `budget` (a `Duration`, e.g. `50ms`). |
| `before_each() callback { … }` | Setup hook. |
| `after_each() callback { … }` | Teardown hook. |
| `assert_eq(a, b, msg)` | Equality check (flat style). No `fw` — matchers report against the framework `init()` set. Same for `assert_true/false`, `assert_str_eq`, `assert_not_eq`, `assert_gt`, `assert_contains`, `assert_null`, `assert_not_null`. |
| `expect_int(x).to_equal(5).to_be_gt(0)` | Fluent assertion chain (subject-first). Int matchers: `to_equal`, `to_be_gt`, `to_be_lt`, `to_be_truthy`, `to_be_falsy`, `not_()`. |
| `expect_str(s).to_contain("x").to_start_with("y")` | Fluent string chain: `to_equal_str`, `to_contain`, `to_start_with`. |
| `expect_int(x).satisfies(pred, msg)` | Fluent escape hatch — run an arbitrary `fn(value)->1/0` predicate mid-chain (`satisfies_str` for strings). |
| `assert_str_eq_diff(actual, expected, msg)` | Exact string equality; on mismatch shows both values with a caret under the first differing byte (Jest-style). |
| `expect_list_size(xs, n, msg)` | A `std.list` of strings has exactly `n` items. Also `expect_list_empty(xs, msg)`, `expect_list_has_str(xs, needle, msg)`. |
| `expect_list_contains_all(xs, needles, msg)` | Every string in `needles` (a `std.list`) appears in `xs`, order-independent. |
| `expect_list_every(xs, pred, msg)` | Every element satisfies `pred` (`fn(string)->1/0`); empty list passes vacuously. |
| `expect_stdout_matches_regex(out, pattern, msg)` | A stdout line matches a PCRE2 regex (per-line, unanchored). |
| `expect_stderr_contains(err, needle, msg)` | Captured child stderr (from `os.run_full`) contains `needle`. |
| `expect_stderr_empty(err, msg)` | Child wrote nothing to stderr. |
| `expect_elapsed_under(elapsed_ns, budget, msg)` | A caller-measured monotonic-ns span is under a `Duration` budget (e.g. `50ms`). |
| `within(5s)` / `without(5s)` | Floating modifier: make the **next** GET matcher (or `eventually`) retry until it passes (`within`) or stops passing (`without`), up to the budget, then auto-revert. `within_poll`/`without_poll` set the poll interval. |
| `eventually(pred, msg)` | Poll a zero-arg predicate (`fn` returning 1/0) under a preceding `within`/`without` budget until it holds (or stops holding); fail if not reached. No budget → one evaluation. |
| `expect_http_get_status(url, status, msg)` | GET `url`; assert transport ok + status. One line, no `resp` lifecycle. Honours a preceding `within`/`without`. |
| `expect_http_get_body_eq(url, want, msg)` | GET `url`; assert 200 + body **exactly** `want`. |
| `expect_http_get_body_contains(url, needle, msg)` | GET `url`; assert 200 + body contains `needle`. |
| `run_summary(fw)` | Report and exit. (Structural — still takes `fw`, as does top-level `describe(fw, name)`.) |

## Custom matchers

A matcher in Aeocha is just **a function that calls `aeocha.fail(msg)` when the
check doesn't hold**. There's no base class, no registration, and no framework
handle to thread — `fail` reports against the framework `init()` set. Aeocha's
own `assert_*`/`expect_*` matchers are written exactly this way, so your matchers
are first-class by construction.

```aether
// Your own matcher — define it anywhere, call it in any it().
expect_even(n: int, msg: string) {
    if n % 2 != 0 {
        aeocha.fail("${msg} — ${n} is not even")
    }
}

aeocha.it("counts are even") callback {
    expect_even(items_processed(), "processed an even count")
}
```

Because failures *accumulate* (a failed matcher records and continues rather than
aborting), several `expect_`/`assert_` calls in one `it()` all report — you see
every problem in a run, not just the first (soft-assert semantics).

For a one-off check without naming a whole matcher, use the fluent escape hatch:

```aether
is_prime(n: int) -> int { ... }   // returns 1 / 0

aeocha.it("is a prime over 10") callback {
    aeocha.expect_int(candidate).to_be_gt(10).satisfies(is_prime, "is prime")
}
```

Extending the *fluent chain* with a brand-new `.to_*` method (vs. a flat matcher
fn) currently only works within the module that declares the subject type —
`IntSubject`/`StrSubject` are exported, but Aether doesn't yet support naming a
qualified type (`aeocha.IntSubject`) in another module's function signature. Use
a flat matcher fn or `satisfies` from a consumer module until that lands.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
