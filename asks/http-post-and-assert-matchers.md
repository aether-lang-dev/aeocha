# Ask: POST-and-assert HTTP matchers (sibling of the GET family)

**Requested by:** aether-ui's grand_perspective AetherUIDriver specs
(`~/scm/aether-ui/tests/grand_perspective/gp_driver.ae`, downstream
consumer). **Status:** DONE (2026-07-08). `expect_http_post_status` and
`expect_http_post_ok` shipped in `aeocha.ae`, mirroring the GET family
(shared retry driver, honour within/without). Fixture coverage +
fail-path verified in the `aeocha_expect_matchers` integration probe
(POST /click 200, /created 201, /forbidden 403). Body-carrying POST form
(`expect_http_post_body_status`) deferred — still no consumer.

## Summary

The GET-and-assert family (`expect_http_get_status` / `_body_eq` /
`_body_contains`, implemented 2026-06-21) has no POST sibling. Add:

```
expect_http_post_status(url, want_status, msg)
expect_http_post_ok(url, msg)                    # any 2xx + no transport error
```

Body-less POSTs are the priority — UI-driver style APIs encode the action
in the URL (`POST /canvas/1/click?x=100&y=90`, `POST /widget/7/toggle`).
A `expect_http_post_body_status(url, body, content_type, want, msg)` form
can follow if a consumer needs it; nobody does today.

## Why

Every consumer that drives a POST-shaped test API re-writes the same
lifecycle boilerplate the GET ask already eliminated for reads:

```aether
post(path: string) -> int {
    req = client.request("POST", string.concat(BASE(), path))
    resp, cerr = client.send_request(req)
    client.request_free(req)
    if string.length(cerr) > 0 { return 0 }
    client.response_free(resp)
    return 1
}
...
ok = post("/canvas/1/click?x=100&y=90")
aeocha.assert_eq(ok, 1, "POST transport")
```

That helper (a) discards the status code, so a 404'd route asserts as a
transport success, and (b) exists verbatim in gp_driver.ae and will be
copied into every app's driver specs as aether-ui converts its remaining
bash suites (calculator, testable, context_menu) to Aeocha.

Like the GET family, the POST matchers should honour a preceding
`within()`/`without()` floating modifier for retry.
