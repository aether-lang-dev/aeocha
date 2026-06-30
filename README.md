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

A test framework tests *your code*. So a real example is two files: the code
under test, and a test that imports and calls it.

**`calc.ae`** — the code under test:

```aether
exports ( add, abs )

add(a: int, b: int) -> int { return a + b }

abs(n: int) -> int {
    if n < 0 { return 0 - n } else { return n }
}
```

**`calc_test.ae`** — the test, which imports `calc` and asserts on what its
functions return:

```aether
import aeocha
import calc

main() {
    fw = aeocha.init()                       // start a test run

    aeocha.describe(fw, "calc.add") {        // group of related tests
        aeocha.it("adds two positives") callback {
            aeocha.assert_eq(calc.add(2, 3), 5, "2 + 3")
        }
        aeocha.it("adds with a negative") callback {
            aeocha.assert_eq(calc.add(10, -4), 6, "10 + (-4)")
        }
    }

    aeocha.describe(fw, "calc.abs") {
        aeocha.it("leaves positives unchanged") callback {
            aeocha.assert_eq(calc.abs(7), 7, "abs(7)")
        }
        aeocha.it("flips negatives") callback {
            aeocha.assert_eq(calc.abs(-7), 7, "abs(-7)")
        }
    }

    aeocha.run_summary(fw)                    // print results, exit 0/1
}
```

Run it (point `AETHER_INCLUDE_PATH` at the directory holding `aeocha.ae`;
`calc.ae` is found next to the test):

```bash
AETHER_INCLUDE_PATH=. ae run calc_test.ae
```

```
calc.add
    ✓ adds two positives
    ✓ adds with a negative
  calc.abs
      ✓ leaves positives unchanged
      ✓ flips negatives

  4 passing
```

Exit code is `0` when everything passes, `1` if anything fails.

### Reading the example, top to bottom

- **`import calc`** — the code under test is an ordinary module; the test imports
  it and calls its functions, asserting on the results. (The assertions check
  `calc.add(...)` / `calc.abs(...)`, not bare literals — you're testing *your
  code*, not arithmetic.)
- **`fw = aeocha.init()`** — creates the test-run context. You capture it once
  and pass it only to the two *structural* calls: the top-level `describe` and
  `run_summary`. (You don't pass it to assertions — see below.)
- **`aeocha.describe(fw, "calc.add") { ... }`** — a group. The `{ ... }` is a
  *trailing block*: everything inside runs in the group's context. Nested
  `describe`/`it`/hooks **omit** the `fw` argument — Aether injects the context
  automatically.
- **`aeocha.it("...") callback { ... }`** — one test case. The `callback { ... }`
  body holds your assertions.
- **`aeocha.assert_eq(actual, expected, msg)`** — an assertion. **No `fw`** —
  matchers report against the run `init()` started. A failed assertion records
  the failure and *keeps going* (so you see every problem in a run, not just the
  first), and turns the surrounding `it` red.
- **`aeocha.run_summary(fw)`** — prints the pass/fail summary and exits `0`/`1`.

### Hooks

`before_each` / `after_each` run around every `it` in their group (omit `fw`):

```aether
aeocha.describe(fw, "Counter") {
    aeocha.before_each() callback { reset() }

    aeocha.it("starts at zero") callback {
        aeocha.assert_eq(count(), 0, "fresh counter")
    }
}
```

### Prefer unqualified calls?

`import aeocha (*)` brings every name into scope so you can drop the `aeocha.`
prefix (`init()`, `describe(fw, ...)`, `assert_eq(...)`). The qualified form
(`import aeocha`) is used throughout this README to make it obvious what comes
from the framework.

> Requires `ae` **v0.331+**. If you edit `aeocha.ae` itself, run
> `rm -rf ~/.aether/cache` first — the compiler cache doesn't notice changes in
> imported modules and will silently run the old version.

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

You can also extend the *fluent chain itself* with your own `.to_*` method, from
your own module. The subject types `IntSubject`/`StrSubject` are exported, and a
matcher is just a free function taking the subject first (it chains via UFCS):

```aether
import aeocha

// A custom fluent matcher — note the bare type name `IntSubject`.
to_be_even(s: IntSubject, msg: string) -> IntSubject {
    if s.value % 2 != 0 { aeocha.fail("${msg} — ${s.value} is not even") }
    return s   // return the subject so the chain continues
}

aeocha.it("count is a positive even") callback {
    aeocha.expect_int(count()).to_be_gt(0).to_be_even("even count")
}
```

Either spelling of the type works: the bare `IntSubject` (in scope from
`import aeocha`) or the qualified `aeocha.IntSubject` — use the qualified form if
another imported module also exports an `IntSubject` and you need to disambiguate.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
