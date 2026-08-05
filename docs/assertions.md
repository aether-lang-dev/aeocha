# Assertions and custom matchers

All matchers report against the framework selected by `init()`. A message is
required where the API accepts `msg`; write the intent of the check rather than
repeating its operands.

## Flat assertions

```aether
aeocha.assert_eq(actual_count, 4, "four jobs completed")
aeocha.assert_str_eq(actual_name, "Ada", "user name")
aeocha.assert_not_null(user, "user was loaded")
```

The flat API covers boolean-like integers, integer equality and ordering,
strings, containment, and pointer nullness. `assert_str_eq_diff` is useful for
long strings: it aligns expected and actual values and points to the first
differing byte.

## Fluent assertions

Fluent assertions hold a typed subject and return it after each matcher:

```aether
aeocha.expect_int(count()).to_be_gt(0).to_equal(4)
aeocha.expect_int(exit_code).not_().to_equal(1)
aeocha.expect_str(name).to_start_with("ae").to_contain("ocha")
```

Integer and string starters are separate because Aether has no receiver-type
overloading. Consequently string equality is `to_equal_str`, while integer
equality is `to_equal`.

`not_()` marks the returned integer subject as negated; matchers later in that
same chain remain negated. Start a new `expect_int` chain to return to positive
matching. `satisfies` and `satisfies_str` apply a caller-supplied predicate
returning `1` or `0`.

## Lists of strings

Collection matchers accept a `std.list` containing strings. They check size,
emptiness, membership, order-independent containment of another list, or a
predicate over every item. `expect_list_every` passes for an empty list.

## Define a flat matcher

A custom matcher is an ordinary function that calls `fail`:

```aether
expect_even(n: int, msg: string) {
    if n % 2 != 0 {
        aeocha.fail("${msg} — ${n} is not even")
    }
}
```

There is no base class or registration step.

## Extend a fluent chain

`IntSubject` and `StrSubject` are exported. A free function whose first
parameter is one of those types participates in Aether's UFCS method syntax:

```aether
to_be_even(s: aeocha.IntSubject, msg: string) -> aeocha.IntSubject {
    if s.value % 2 != 0 { aeocha.fail("${msg} — ${s.value} is not even") }
    return s
}

aeocha.expect_int(count()).to_be_gt(0).to_be_even("even count")
```

Return the subject so callers can continue the chain. Use the qualified subject
type when another import exports a type with the same name.

See [API reference](api-reference.md#assertions) for every signature.
