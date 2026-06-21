# Ask: high-level GET-and-assert HTTP matchers

**Requested by:** the `aeo` orchestrator's integration tests (downstream
consumer). **Status:** implemented (2026-06-21).

## Summary

Add a small family of one-call HTTP-GET matchers that hide the
request/send/free lifecycle:

```
expect_http_get_status(fw, url, want_status, msg)
expect_http_get_body_eq(fw, url, want_body, msg)        # body == want_body (exact)
expect_http_get_body_contains(fw, url, needle, msg)     # body contains needle
```

Each performs the GET, checks the transport, asserts, and frees the
response — so a test asserts an HTTP response in **one line**.

## Why

Aeocha already has the *low-level* HTTP matchers
(`expect_http_status`, `expect_http_no_error`, `expect_http_body_contains`,
`expect_http_header`, `expect_http_body_json_field`), but they all take a
`resp` the caller must build and free themselves. So every consumer
re-writes the same lifecycle boilerplate:

```aether
req = client.request("GET", url)
resp, cerr = client.send_request(req)
client.request_free(req)
if cerr != "" {
    aeocha.fail(fw, "${msg} — transport error: ${cerr}")
} else {
    aeocha.expect_http_status(fw, resp, 200, "${msg} (200)")
    aeocha.expect_http_body_contains(fw, resp, want, "${msg}")
    client.response_free(resp)
}
```

This shows up verbatim in **two** aeo specs (`spec_nested_system.ae`,
`spec_integration_app.ae`), each wrapping it in a private `_http_body_is`
helper — and in aeocha's own
`tests/integration/aeocha_expect_matchers/probe.ae`. Three independent
copies of the same dance is the signal it belongs in the framework.

This is squarely aeocha's stated mandate (LLM.md):

> Maintain the `expect_*` matchers for process and HTTP testing. These are
> designed to be **high-level** and **reduce boilerplate** in integration
> tests.

The current `expect_http_*` are *not* high-level — they make the caller do
the request lifecycle. A GET-and-assert matcher is the missing high-level
layer.

## Correctness note (why a `_eq` AND a `_contains`)

The aeo specs assert arithmetic over HTTP: `GET /add/2/3` must return `"5"`.
The existing `expect_http_body_contains` is a **substring** check, so `"5"`
would also match a body of `"50"` — wrong for an exact result. Hence the
family needs a body-**equals** matcher (`expect_http_get_body_eq`), not only
contains. (Our local `_http_body_is` currently uses contains and inherits
this looseness — exactly the kind of footgun a framework matcher should
remove.)

## Suggested shape

Mirror the existing matchers' signature style (`fw` first, `msg` last),
reuse the existing `expect_http_*` internally so semantics stay consistent:

```aether
// GET url, assert transport ok + status 200 + body EXACTLY equals want.
expect_http_get_body_eq(fw: ptr, url: string, want: string, msg: string) {
    req = client.request("GET", url)
    resp, cerr = client.send_request(req)
    client.request_free(req)
    if cerr != "" {
        fail(fw, "${msg} — transport error: ${cerr}")
    } else {
        expect_http_status(fw, resp, 200, "${msg} (200)")
        expect_http_body_eq(fw, resp, want, "${msg}")   // new exact-body matcher
        client.response_free(resp)
    }
}
```

(`expect_http_body_eq` — exact-body sibling of the existing
`expect_http_body_contains` — would be useful on its own too, for callers
who already hold a `resp`.)

Optional: a status-override variant for non-200 expectations, and `_post_*`
twins later. Keeping the first cut to GET + the three asserts above covers
the integration-test 80%.

## Impact

`aeo`'s specs drop their private `_http_body_is` helper and call the
framework matcher directly — fewer lines, no per-consumer lifecycle bugs,
and the exact-vs-substring choice becomes explicit at the call site.
