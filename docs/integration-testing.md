# Integration testing

Aeocha provides matchers for captured processes and HTTP responses. They use
the same soft-failure behaviour as ordinary assertions.

## Child processes

`os.run_capture(prog, argv, env)` returns stdout, exit status, and a spawn-error
string. Its third result is not the child's stderr.

```aether
out, exit_code, spawn_err = os.run_capture(prog, argv, null)
aeocha.expect_no_spawn_error(spawn_err, "child started")
aeocha.expect_exit(exit_code, 0, "child exited cleanly")
aeocha.expect_stdout_contains(out, "ready", "child became ready")
```

The stdout API can count lines, extract a zero-based whitespace-delimited field
from the first line with a prefix, compare the trimmed remainder after a prefix,
or match a line against a glob or PCRE2 regex. Regex matching is per-line and
unanchored unless the pattern supplies anchors; it requires `libpcre2-8`.

Use `os.run_full(prog, argv, env, stdin)` for separate child stdout and stderr:

```aether
out, err, exit_code, spawn_err = os.run_full(prog, argv, null, "")
aeocha.expect_no_spawn_error(spawn_err, "child started")
aeocha.expect_stderr_empty(err, "child emitted no diagnostics")
```

## High-level HTTP matchers

High-level GET and body-less POST matchers perform the request and manage the
request/response lifecycle:

```aether
aeocha.expect_http_get_status(url, 200, "health endpoint")
aeocha.expect_http_get_body_contains(url, "ready", "service is ready")
aeocha.expect_http_post_ok(action_url, "action accepted")
```

GET body matchers require status 200 as well as the requested body condition.
`expect_http_post_ok` accepts any 2xx response.

## Low-level HTTP matchers

Use the low-level family when the caller already owns a response. It can check
transport success, status, exact or partial body content, a header, or one
compact top-level JSON string field. The caller remains responsible for request
and response cleanup.

Header names are case-insensitive and values are exact. The JSON-field matcher
looks for compact `"key":"value"` text; use `std.json` for nested, non-string,
escaped, or pretty-printed JSON.

## Retry modifiers

`within` makes the next retryable operation poll until its condition holds.
`without` polls until the condition stops holding. They are positional,
one-shot modifiers and automatically revert after the operation consumes them.

```aether
aeocha.within(5s)
aeocha.expect_http_get_status("http://127.0.0.1:8080/ready", 200,
                              "service becomes ready")

aeocha.without_poll(2s, 100ms)
aeocha.eventually(job_is_running, "job stops")
```

`within_poll` and `without_poll` select the poll interval. The default is 50ms.
Without a modifier, `eventually` evaluates once and HTTP matchers make one
request.

See the [API reference](api-reference.md#process-matchers) for exact signatures.
