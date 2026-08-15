# Core concepts

## Framework context

`init()` returns a framework context and stores it as the process's current
framework. Top-level `describe` and `run_summary` take the returned `fw`;
assertions read the ambient context and therefore do not take it.

Aeocha supports one current framework per process. A second `init()` replaces
the first ambient context.

## Suites and context injection

The top-level suite has no enclosing block, so it is written as
`describe(fw, name)`. Its trailing block receives an injected `_ctx`; nested
`describe`, `it`, `it_within`, `before_each`, and `after_each` calls omit `fw`.

```aether
aeocha.describe(fw, "outer") {
    aeocha.describe("inner") {
        aeocha.it("does something") callback { ... }
    }
}
```

Tests execute as their `it` calls are reached; Aeocha does not perform its own
source-file discovery. Invoke a test program with `ae run`, or use tooling that
launches Aeocha test binaries.

## Hooks

`before_each` and `after_each` apply to tests in their suite and descendant
suites. Before hooks run outermost to innermost. After hooks run innermost to
outermost.

```aether
aeocha.describe(fw, "Counter") {
    aeocha.before_each() callback { reset() }
    aeocha.after_each() callback { close_resources() }

    aeocha.it("starts at zero") callback {
        aeocha.assert_eq(count(), 0, "fresh counter")
    }
}
```

## Soft failures

`fail(msg)` records and prints a failure but does not abort the callback. All
flat, fluent, process, and HTTP matchers ultimately use `fail`, so multiple
checks can report in one test. Any recorded failure makes that `it` fail.

The structured report retains the first failure message for each failed test;
the terminal output displays every failure.

## Duration budgets

`it_within` runs a normal test and additionally fails it when elapsed monotonic
time meets or exceeds an Aether `Duration` budget:

```aether
aeocha.it_within("responds promptly", 50ms) callback {
    call_service()
}
```

`expect_elapsed_under` performs the same kind of comparison for a monotonic
nanosecond span measured by the caller.

## Reporting and exit status

Call `run_summary(fw)` once after all suites. It prints totals and calls
`exit(1)` if failures were recorded; a successful run returns normally.

When the parent process sets `AE_SPEC_FORMAT` (`tap` or `aeocha`) and
`AE_SPEC_REPORT` (a file path), `run_summary` also writes a structured report
to that file — the documented env-file transport consumed by Aether's `aeb`
tooling and `ae test --format`. The `aeocha` format contains run totals,
duration, and one PASS or FAIL row per test.

Because the successful path returns, a test that starts a permanently running
actor or server should explicitly terminate it or end `main()` with `exit(0)`.
