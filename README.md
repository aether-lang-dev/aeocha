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
| `before_each() callback { … }` | Setup hook. |
| `after_each() callback { … }` | Teardown hook. |
| `assert_eq(fw, a, b, msg)` | Equality check (flat style). |
| `expect_int(x).to_equal(5).to_be_gt(0)` | Fluent assertion chain (subject-first; no `fw` in the chain). Int matchers: `to_equal`, `to_be_gt`, `to_be_lt`, `to_be_truthy`, `to_be_falsy`, `not_()`. |
| `expect_str(s).to_contain("x").to_start_with("y")` | Fluent string chain: `to_equal_str`, `to_contain`, `to_start_with`. |
| `expect_stdout_matches_regex(fw, out, pattern, msg)` | A stdout line matches a PCRE2 regex (per-line, unanchored). |
| `expect_stderr_contains(fw, err, needle, msg)` | Captured child stderr (from `os.run_full`) contains `needle`. |
| `expect_stderr_empty(fw, err, msg)` | Child wrote nothing to stderr. |
| `expect_elapsed_under(fw, elapsed_ns, budget, msg)` | A caller-measured monotonic-ns span is under a `Duration` budget (e.g. `50ms`). |
| `within(5s)` / `without(5s)` | Floating modifier: make the **next** GET matcher retry until it passes (`within`) or stops passing (`without`), up to the budget, then auto-revert. `within_poll`/`without_poll` set the poll interval. |
| `expect_http_get_status(fw, url, status, msg)` | GET `url`; assert transport ok + status. One line, no `resp` lifecycle. Honours a preceding `within`/`without`. |
| `expect_http_get_body_eq(fw, url, want, msg)` | GET `url`; assert 200 + body **exactly** `want`. |
| `expect_http_get_body_contains(fw, url, needle, msg)` | GET `url`; assert 200 + body contains `needle`. |
| `run_summary(fw)` | Report and exit. |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
