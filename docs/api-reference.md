# API reference

This page lists every symbol exported by `aeocha.ae`. Signatures show explicit
parameters; `_ctx` is injected by an enclosing trailing block where noted.

## Framework and suites

| Signature | Behaviour |
|-----------|-----------|
| `init() -> ptr` | Creates a framework context and makes it ambient. One current framework is supported per process. |
| `describe(_ctx: ptr, description: string) -> ptr` | Prints and creates a suite. Pass `fw` at top level; nested calls receive `_ctx` automatically. |
| `it(_ctx: ptr, description: string, test_fn: fn)` | Runs a test callback. `_ctx` is injected inside a suite. |
| `it_within(_ctx: ptr, description: string, budget: Duration, test_fn: fn)` | Runs a test and fails it when elapsed time is at least `budget`. |
| `before_each(_ctx: ptr, setup: fn)` | Registers a hook inherited by descendant suites. Runs outermost first. |
| `after_each(_ctx: ptr, teardown: fn)` | Registers a hook inherited by descendant suites. Runs innermost first. |
| `run_summary(fw: ptr)` | Prints totals, emits an IPC report when connected, and exits 1 on failure. |

Trailing-block syntax supplies callback parameters:

```aether
aeocha.describe(fw, "suite") {
    aeocha.before_each() callback { setup() }
    aeocha.it_within("case", 100ms) callback { exercise() }
}
```

## Assertions

All assertion failures are soft: they call `fail`, record the failure, and
return to the caller.

| Signature | Behaviour |
|-----------|-----------|
| `fail(msg: string)` | Records and prints a failure against the ambient framework. |
| `assert_true(condition: int, msg: string)` | Requires a nonzero value. |
| `assert_false(condition: int, msg: string)` | Requires zero. |
| `assert_eq(actual: int, expected: int, msg: string)` | Requires integer equality. |
| `assert_not_eq(actual: int, expected: int, msg: string)` | Requires integer inequality. |
| `assert_gt(actual: int, expected: int, msg: string)` | Requires `actual > expected`. |
| `assert_str_eq(actual: string, expected: string, msg: string)` | Requires exact string equality. |
| `assert_str_eq_diff(actual: string, expected: string, msg: string)` | Exact equality with a caret at the first differing byte. |
| `assert_contains(haystack: string, needle: string, msg: string)` | Requires substring containment. |
| `assert_null(value: ptr, msg: string)` | Requires a null pointer. |
| `assert_not_null(value: ptr, msg: string)` | Requires a non-null pointer. |
| `expect_elapsed_under(elapsed_ns: long, budget: Duration, msg: string)` | Requires a caller-measured monotonic span to be below the budget. |

## Fluent assertions

`IntSubject` has public fields `value: int` and `negated: int`. `StrSubject` has
public fields `value: string` and `negated: int`.

| Signature | Behaviour |
|-----------|-----------|
| `expect_int(v: int) -> IntSubject` | Starts an integer chain. |
| `expect_str(v: string) -> StrSubject` | Starts a string chain and copies the value. |
| `not_(s: IntSubject) -> IntSubject` | Returns a negated integer subject; subsequent matchers on that subject remain negated. |
| `to_equal(s: IntSubject, want: int) -> IntSubject` | Integer equality. |
| `to_be_gt(s: IntSubject, bound: int) -> IntSubject` | Integer greater-than. |
| `to_be_lt(s: IntSubject, bound: int) -> IntSubject` | Integer less-than. |
| `to_be_truthy(s: IntSubject) -> IntSubject` | Requires nonzero. |
| `to_be_falsy(s: IntSubject) -> IntSubject` | Requires zero. |
| `to_equal_str(s: StrSubject, want: string) -> StrSubject` | String equality. |
| `to_contain(s: StrSubject, needle: string) -> StrSubject` | String containment. |
| `to_start_with(s: StrSubject, prefix: string) -> StrSubject` | String prefix. |
| `satisfies(s: IntSubject, pred: fn, msg: string) -> IntSubject` | Requires `pred(value) == 1`. |
| `satisfies_str(s: StrSubject, pred: fn, msg: string) -> StrSubject` | String equivalent of `satisfies`. |

`not_` is exported only for `IntSubject`; the current string chain has no
negation function.

## String-list matchers

These functions expect a `std.list` of strings.

| Signature | Behaviour |
|-----------|-----------|
| `expect_list_size(xs: ptr, want: int, msg: string)` | Requires exactly `want` entries. |
| `expect_list_empty(xs: ptr, msg: string)` | Requires an empty list. |
| `expect_list_has_str(xs: ptr, needle: string, msg: string)` | Requires one equal string. |
| `expect_list_contains_all(xs: ptr, needles: ptr, msg: string)` | Requires every string in `needles`, in any order. |
| `expect_list_every(xs: ptr, pred: fn, msg: string)` | Requires every entry to satisfy the predicate; empty lists pass. |

## Process matchers

| Signature | Behaviour |
|-----------|-----------|
| `expect_exit(exit_code: int, want: int, msg: string)` | Requires an exit status. |
| `expect_no_spawn_error(err: string, msg: string)` | Requires `os.run_capture`/`run_full` spawn error to be empty. |
| `expect_stdout_contains(out: string, needle: string, msg: string)` | Requires a stdout substring. |
| `expect_stdout_line_count(out: string, want: int, msg: string)` | Requires a newline-aware line count. |
| `expect_stdout_line_field(out: string, prefix: string, n: int, want: string, msg: string)` | On the first prefixed line, compares zero-based whitespace field `n`. |
| `expect_stdout_line_after(out: string, prefix: string, want: string, msg: string)` | Compares the trimmed remainder of the first prefixed line. |
| `expect_stdout_matches(out: string, pattern: string, msg: string)` | Requires one line matching a glob. |
| `expect_stdout_matches_regex(out: string, pattern: string, msg: string)` | Requires one line matching an unanchored PCRE2 regex. |
| `expect_stderr_contains(err: string, needle: string, msg: string)` | Requires a substring in `os.run_full` child stderr. |
| `expect_stderr_empty(err: string, msg: string)` | Requires empty child stderr. |

## Low-level HTTP matchers

The caller creates and frees the response.

| Signature | Behaviour |
|-----------|-----------|
| `expect_http_no_error(resp: ptr, msg: string)` | Requires a non-null response. |
| `expect_http_status(resp: ptr, want: int, msg: string)` | Requires an HTTP status. |
| `expect_http_body_contains(resp: ptr, needle: string, msg: string)` | Requires a body substring. |
| `expect_http_body_eq(resp: ptr, want: string, msg: string)` | Requires exact body equality. |
| `expect_http_header(resp: ptr, name: string, want: string, msg: string)` | Requires an exact header value; names are case-insensitive. |
| `expect_http_body_json_field(resp: ptr, key: string, want: string, msg: string)` | Finds compact top-level `"key":"value"` text in the body. |

## High-level HTTP matchers

These functions perform the request and manage its lifecycle.

| Signature | Behaviour |
|-----------|-----------|
| `expect_http_get_status(url: string, want_status: int, msg: string)` | GET and require a status. |
| `expect_http_get_body_eq(url: string, want: string, msg: string)` | GET and require status 200 plus exact body. |
| `expect_http_get_body_contains(url: string, needle: string, msg: string)` | GET and require status 200 plus a body substring. |
| `expect_http_post_status(url: string, want_status: int, msg: string)` | Body-less POST and require a status. |
| `expect_http_post_ok(url: string, msg: string)` | Body-less POST and require any 2xx status. |

## Retry and eventual checks

| Signature | Behaviour |
|-----------|-----------|
| `within(budget: Duration)` | Makes the next retryable matcher poll until it passes, every 50ms. |
| `within_poll(budget: Duration, poll: Duration)` | `within` with an explicit interval. |
| `without(budget: Duration)` | Polls until the next condition stops holding, every 50ms. |
| `without_poll(budget: Duration, poll: Duration)` | `without` with an explicit interval. |
| `eventually(pred: fn, msg: string)` | Evaluates a zero-argument `fn` returning 1/0 under the pending modifier; once without one. |

The modifier is ambient, positional, and consumed by one operation. Supported
HTTP operations and `eventually` perform a single attempt when no modifier is
pending.
