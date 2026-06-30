# mutate — mutation testing for Aeocha-tested code

Mutation testing measures **how good your tests are**. It changes the code
under test (the "SUT") one tiny edit at a time — `+` becomes `-`, `>` becomes
`<` — and re-runs your test suite for each change. A change your tests *catch*
is a **killed** mutant (good). A change that slips through is a **survivor** —
proof your tests have a gap.

This is a small, adjacent tool (not part of `aeocha.ae`). It's written in Aether
and uses Aeocha purely as an **oracle**: `run_summary` exits non-zero on failure,
so a non-zero `ae run` of your test file means the mutant was killed.

## Why it's an outer driver (not a test helper)

The compiler has already run by the time any test executes, so a mutant can't be
produced in-process — there's no source or AST left to perturb, only compiled
machine code. Mutation therefore has to:

1. edit the SUT **source on disk**,
2. clear the build cache and **rebuild**,
3. **re-run** the (unchanged) test suite and read its exit code,

once per mutant. `mutate.ae` is that outer loop. Your test file is completely
unaware mutation is happening.

## Usage

Run from the directory that is your include-path root (where `aeocha.ae` is
resolvable), passing the SUT, its test, and the include path:

```bash
ae run contrib/mutate/mutate.ae -- <sut.ae> <test.ae> <include_path>
```

Working example (from the repo root):

```bash
ae run contrib/mutate/mutate.ae -- \
    contrib/mutate/example/calc.ae \
    contrib/mutate/example/calc_test.ae \
    "$PWD"
```

Output:

```
Aeocha mutation testing
  SUT:  contrib/mutate/example/calc.ae
  test: contrib/mutate/example/calc_test.ae

  baseline: suite passes on unmutated SUT ✓

  killed    GTE->LT  (occurrence 0)
  killed    LTE->GT  (occurrence 0)
  killed    EQ->NE  (occurrence 0)
  killed    ADD->SUB  (occurrence 0)
  killed    SUB->ADD  (occurrence 0)
  killed    MUL->DIV  (occurrence 0)
  killed    MUL->DIV  (occurrence 1)
  SURVIVED  AND->OR  (occurrence 0)

  7/8 mutants killed — mutation score 87%
  1 survived (test gaps):
    - AND->OR #0
```

The surviving `AND->OR` is real: the example's `in_range` test only checks an
*in-range* value, never one below `lo` or above `hi`, so flipping `&&` to `||`
still passes. Add the boundary cases and it gets killed — that's the tool doing
its job. (The example test ships with that gap on purpose.)

## Mutation operators (core set)

Each is matched **whitespace-padded** (`" + "`, `" > "`), so normal Aether
spacing is required for a site to be seen:

| Operator | Mutation |
|---|---|
| `+` ↔ `-` | arithmetic |
| `*` → `/` | arithmetic |
| `>` `<` `>=` `<=` | comparison flips |
| `==` ↔ `!=` | equality flips |
| `&&` ↔ `\|\|` | boolean |

## Reading the result

- **Mutation score** = killed / total. Higher is better; 100% means every
  single-operator change to the SUT was caught by some test.
- **Survivors** are your to-do list: each one is a behaviour your tests don't
  pin down. Either add a test that distinguishes it, or convince yourself it's
  an *equivalent mutant* (see caveats).

## Honest limitations

This is a Tier-1, text-based tool. Know what it does and doesn't do:

- **Text, not AST.** Operators are matched as padded tokens. `++`, `+=`, and
  operators that abut other characters are skipped. A padded operator *inside a
  string literal* can be mutated — a false mutant. Eyeball survivors with that
  in mind.
- **Equivalent mutants.** Some changes don't alter behaviour (e.g. `<` → `<=` on
  a boundary your code never reaches). They "survive" without being real gaps.
  This is inherent to mutation testing, not a bug here.
- **Slow.** Every mutant pays a full cache-clear + recompile + run — there's no
  warm-cache reuse (the cache-clear is mandatory, or you'd test a stale build).
  Point it at a focused SUT, not your whole codebase.
- **Crash safety.** `mutate.ae` restores the original SUT at the end of the run
  (verified byte-identical). But it mutates the real file in place, so if the
  driver is killed mid-run (Ctrl-C, OOM), the SUT is left mutated — recover with
  `git checkout <sut.ae>`. Run it on a clean working tree.

## What a richer version would need

Precise, false-mutant-free mutation needs AST-level edits — an `ae mutate`
subcommand or `ae inspect` emitting expression positions. That's an upstream
Aether feature, not something this text-based driver can do.
