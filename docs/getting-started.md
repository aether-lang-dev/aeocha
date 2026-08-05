# Getting started

This guide takes a two-file Aether program from source to a passing Aeocha test.

## Prerequisites

Use Aether `ae` v0.494.0 or newer. Install a prebuilt toolchain from the
[Aether releases](https://github.com/aether-lang-dev/aether/releases/latest),
or use an existing `ae` to run `ae upgrade`. Building Aether from source is a
fallback, not the normal prerequisite for using Aeocha.

Aeocha itself must be in a module search directory:

```bash
git clone https://github.com/aether-lang-org/aeocha.git /path/to/aeocha
export AETHER_LIB_DIR=/path/to/aeocha
```

`AETHER_LIB_DIR` is a PATH-style list. The equivalent command-line option is
`--lib /path/to/aeocha`. For a small experiment, copying `aeocha.ae` into the
current working directory also works.

## Create the example

Start with this layout:

```text
example/
├── calc.ae
└── calc_test.ae
```

Put the production code in `calc.ae`:

```aether
exports ( add, abs )

add(a: int, b: int) -> int { return a + b }

abs(n: int) -> int {
    if n < 0 { return 0 - n } else { return n }
}
```

Put its tests in `calc_test.ae`:

```aether
import aeocha
import calc

main() {
    fw = aeocha.init()

    aeocha.describe(fw, "calc") {
        aeocha.it("adds two positives") callback {
            aeocha.assert_eq(calc.add(2, 3), 5, "2 + 3")
        }

        aeocha.it("flips a negative absolute value") callback {
            aeocha.expect_int(calc.abs(-7)).to_equal(7)
        }
    }

    aeocha.run_summary(fw)
}
```

From `example/`, run:

```bash
AETHER_LIB_DIR=/path/to/aeocha ae run calc_test.ae
```

The run prints both cases and a `2 passing` summary. Its process status is `0`
when all tests pass and `1` when any assertion fails.

## Read the test from top to bottom

- `import aeocha` keeps framework calls visibly qualified. Use
  `import aeocha (*)` if you prefer bare calls.
- `init()` creates the run context and also makes it ambient for matchers.
- The top-level `describe` takes `fw`. Aether injects a suite context into its
  trailing block, so nested suites, hooks, and tests omit that argument.
- `it(name) callback { ... }` defines and runs a test case.
- Assertions do not take `fw`; they report through the ambient context.
- `run_summary(fw)` prints totals and returns failure status when needed.

## See a failure

Change the first expected value from `5` to `6` and rerun. Aeocha prints the
failure at the assertion, marks the surrounding test red, continues with later
tests, and finishes with passing and failing totals.

Assertions are soft: several failed assertions in one test are all printed.
Read [Core concepts](concepts.md) next, or jump to the
[API reference](api-reference.md).
