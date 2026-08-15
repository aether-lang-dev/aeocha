# Ask: an optional "why" message on the fluent matchers

**Requested by:** the `aeo` orchestrator's specs (downstream consumer).
**Status:** DELIVERED upstream — refiled as
[aether#1576](https://github.com/aether-lang-dev/aether/issues/1576)
on 2026-08-14 and landed in aether 0.542.0: the fluent value matchers
take an optional trailing `msg` (default arguments resolve through
UFCS chaining, so neither breaking sweep nor `*_because` variants were
needed), and `to_equal_str` upgrades to the caret-aligned diff at ≥24
chars. Archived here for provenance; originally requested 2026-06-28.

## Summary

The fluent chain matchers (`to_equal`, `to_equal_str`, `to_be_gt`, `to_be_lt`,
`to_contain`, `to_start_with`, `to_be_truthy`, `to_be_falsy`) auto-generate
their failure text (`expected '5', got '7'`) and have **no way to carry the
operator's intent message**. The flat asserts already do — `assert_str_eq(a, b,
msg)`. Please add an optional `msg` to the fluent matchers so a chain can say
*why* a check matters, not just *what* the values were:

```
expect_str(got).to_equal_str(want, "explicit budget wins over within()")
expect_int(n).to_be_gt(0, "a derived attempt budget is never zero")
```

`satisfies(s, pred, msg)` already takes a `msg` — so the precedent (and the
verdict plumbing) is in the API; this extends it to the value-comparison
matchers.

## Why

aeo nearly converted its ~243 spec assertions to the fluent chain (now that
cross-module UFCS #934 + ambient-fw #937 make it work — thank you). We backed
off, because **158 of those assertions are `assert_str_eq(computed, "expected",
"why")` where the "why" is documentation the value can't convey** — e.g.:

```aether
aeocha.assert_str_eq(get_depends("app"), "db", "app ◄ db (cross-VM by name)")
aeocha.assert_str_eq(get_budget("old"),  "12", "explicit health_budget wins over within()")
aeocha.assert_str_eq(net_kind("egress->db:6379"), "internal", "peer egress -> internal net")
```

In the flat form the message *is* the test's intent. The current fluent form
would render only `expected 'internal', got 'shared'` — losing "peer egress ->
internal net", which is the thing a reader (or a failing-CI triager) actually
needs. So today the choice is: **fluent chain XOR an intent message**, and for
snapshot-style assertions (compare a computed value to a constant, document the
rule it proves) the message wins — which keeps consumers on the flat API even
where a chain would otherwise read better.

With an optional `msg`, the chain becomes strictly additive: you get the fluent
ergonomics *and* the documented intent, and a multi-check chain can annotate each
link:

```aether
expect_int(get_budget("db"))
    .to_equal(60, "within(30s)/every(500ms) -> 60 attempts")
    .to_be_gt(0,  "a derived budget is never zero")
```

## Suggested shape

Add a trailing optional `msg` (default `""` → keep today's auto-generated text;
non-empty → prefix or replace it):

```
to_equal(s: IntSubject, want: int, msg: string) -> IntSubject
to_equal_str(s: StrSubject, want: string, msg: string) -> StrSubject
to_be_gt(s: IntSubject, bound: int, msg: string) -> IntSubject
to_be_lt(s: IntSubject, bound: int, msg: string) -> IntSubject
to_contain(s: StrSubject, needle: string, msg: string) -> StrSubject
to_start_with(s: StrSubject, prefix: string, msg: string) -> StrSubject
to_be_truthy(s: IntSubject, msg: string) -> IntSubject
to_be_falsy(s: IntSubject, msg: string) -> IntSubject
```

Failure text could be `"${msg} — expected '${want}', got '${s.value}'"` when
`msg != ""` (the message frames it; the auto-text still shows the values), else
the current text unchanged. Aether is fixed-arity (no overloading), so this is a
signature change, not an overload — which means it's **breaking for existing
fluent-chain callers**. Two ways to land it:

- **(a)** make `msg` required and sweep the (currently few) fluent callers, or
- **(b)** add parallel `*_because(s, want, msg)` variants and leave the bare ones
  as-is (no break, but two names per matcher).

(a) is cleaner if the fluent API is still young; (b) is non-breaking. Your call —
you own the API's churn budget.

## Impact

Unblocks aeo (and any consumer whose tests are "assert a computed value equals a
constant, and document the rule") from adopting the fluent chain at all. Without
it, those consumers stay on the flat asserts permanently — not because the chain
is worse, but because it can't carry the one thing those tests most need. With
it, the fluent chain becomes the strictly-better option everywhere, and aeo would
sweep its ~243 assertions over to it.
