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
| `assert_eq(fw, a, b, msg)` | Equality check. |
| `run_summary(fw)` | Report and exit. |

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
