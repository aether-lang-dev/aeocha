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
machine code. Mutation therefore has to, once per mutant:

1. edit the SUT **source on disk** and clear the build cache,
2. **`ae check`** the test — if the mutant doesn't type-check, it's *no-compile*
   (excluded from the score; a mutant that won't build was never really tested),
3. **`ae build`** the test to a binary and run it with
   `AE_SPEC_FORMAT=aeocha` + `AE_SPEC_REPORT=<file>` set, **reading the
   structured report** from that file rather than scraping stdout. The report's
   `failed=N` is the verdict: `N > 0` → killed, `N == 0` → survived.

`mutate.ae` is that outer loop; your test file is completely unaware mutation is
happening. Using the structured report (not just a process exit code) is what lets
the tool tell *killed* (a test actually failed) apart from *no-compile* (the
mutation produced invalid code) — so a non-compiling mutant never inflates the
score by masquerading as a kill.

> Compiler note: the no-compile gate greps `ae check`'s output for an `error[`
> diagnostic rather than trusting its exit code. On the current `ae`, both
> `ae check` and `ae build` can print a compile error to stderr yet still exit 0
> (and `build` will even emit a binary linked against a stale module) — see
> aether #953. Grepping the diagnostic is the reliable signal until that's fixed.

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

`contrib/mutate/example/` is the **same `calc`** as the top-level README's Quick
Start — `calc.ae` (the code under test) plus `calc_test.ae` (the Aeocha suite).
Mutation testing asks how well that suite tests that code. Output:

```
Aeocha mutation testing
  SUT:  contrib/mutate/example/calc.ae
  test: contrib/mutate/example/calc_test.ae

  baseline: suite passes on unmutated SUT ✓

  killed     calc.ae:6  ADD->SUB
  killed     calc.ae:9  SUB->ADD
  killed     calc.ae:9  LT->GT

  3/3 mutants killed — mutation score 100%
```

100% — every single-operator change to `calc.ae` was caught by `calc_test.ae`.
Each line is one mutant, anchored to its source location: `calc.ae:6 ADD->SUB`
flips the `+` in `add`; `calc.ae:9 SUB->ADD` flips the `0 - n` in `abs`;
`calc.ae:9 LT->GT` flips the `n < 0` guard. The suite asserts both branches of
`abs` and an addition with a negative, so all three are killed.

### What a survivor looks like

A survivor is the interesting case — it's a *test gap*. Delete the negative-input
case from `calc_test.ae` (the `abs(-7)` assertion), and the `SUB->ADD` mutant
suddenly survives:

```
  killed     calc.ae:6  ADD->SUB
  SURVIVED   calc.ae:9  SUB->ADD
  killed     calc.ae:9  LT->GT

  2/3 mutants killed — mutation score 66%
  1 survived (test gaps):
    - calc.ae:9  SUB->ADD
```

The survivor line tells you exactly where to look — `calc.ae:9` — not just which
operator.

`SUB->ADD` flips the `0 - n` in `abs` to `0 + n` — which only changes the result
for a *negative* input. With `abs(-7)` removed, nothing feeds `abs` a negative, so
the mutant goes unnoticed. (Note `LT->GT` is still killed: flipping the `n < 0`
guard sends the positive `abs(7)` down the negation branch, and that case is still
tested.) Add the negative-input assertion back and `SUB->ADD` returns to killed.
That is the whole point — survivors are your missing tests.

## Mutation operators (core set)

Operator mutators are matched **whitespace-padded** (`" + "`, `" > "`), so normal
Aether spacing is required for a site to be seen — and a padded operator that sits
*inside a string literal* is skipped (the tool tracks string boundaries, so
`"a + b"` in your code is never mutated as arithmetic).

| Operator | Mutation |
|---|---|
| `+` ↔ `-` | arithmetic |
| `*` → `/` | arithmetic |
| `>` `<` `>=` `<=` | comparison flips |
| `==` ↔ `!=` | equality flips |
| `&&` ↔ `\|\|` | boolean |

String-literal mutators target the literal's *content* (quotes preserved):

| Mutator | Mutation |
|---|---|
| `STR->EMPTY` | a non-empty `"foo"` → `""` (catches tests that don't pin the returned string) |
| `EMPTY->NONEMPTY` | an empty `""` → a sentinel (catches an unchecked empty-string case) |

## Reading the result

- **Mutation score** = killed / (killed + survived). Higher is better; 100% means
  every single-operator change that *compiled* was caught by some test.
- **Survivors** are your to-do list: each one is reported as `file:line  MUTATION`
  so you can jump straight to the unguarded code. Either add a test that
  distinguishes it, or convince yourself it's an *equivalent mutant* (see caveats).
- **No-compile** mutants (the mutation produced invalid code) are reported as
  `(N excluded — did not compile)` and left out of the denominator — they were
  never really tested, so they neither help nor hurt the score. With the core
  operator set they're rare (most operator swaps stay valid), but the category
  keeps the score honest when they happen.

## Honest limitations

This is a Tier-1, text-based tool. Know what it does and doesn't do:

- **Text, not AST.** Operators are matched as padded tokens, so `++`, `+=`, and
  operators that abut other characters are skipped. The tool *is* string-boundary
  aware — a padded operator inside a `"..."` literal won't be mutated as code, and
  string-literal mutators only touch real literals. The remaining blind spot is
  **comments**: a `"..."` or a padded operator written in a `//` comment is still
  treated as source, so it can produce a harmless false mutant (it changes nothing
  the suite sees → survives). Keep operator/quote characters out of comments in a
  SUT you mutate, or expect a stray survivor.
- **Equivalent mutants.** Some changes don't alter behaviour (e.g. `<` → `<=` on
  a boundary your code never reaches). They "survive" without being real gaps.
  This is inherent to mutation testing, not a bug here.
- **Slow.** Every mutant pays a cache-clear + `ae check` + `ae build` + run — and
  the cache-clear is mandatory (an imported-module edit doesn't invalidate the
  cache, so you'd otherwise test a stale build). Three compiler invocations per
  mutant, no warm-cache reuse — point it at a focused SUT, not your whole codebase.
- **Crash safety.** `mutate.ae` restores the original SUT at the end of the run
  (verified byte-identical). But it mutates the real file in place, so if the
  driver is killed mid-run (Ctrl-C, OOM), the SUT is left mutated — recover with
  `git checkout <sut.ae>`. Run it on a clean working tree.

## What a richer version would need

Precise, false-mutant-free mutation needs AST-level edits — an `ae mutate`
subcommand or `ae inspect` emitting expression positions. That's an upstream
Aether feature, not something this text-based driver can do.
