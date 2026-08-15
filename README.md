# Aeocha

Aeocha is a BDD-style test framework for
[Aether](https://github.com/aether-lang-org/aether): nested suites, hooks, soft
assertions, fluent expectations, timing helpers, and process and HTTP matchers.

Most of it now ships inside Aether's own stdlib — `std.spec` (framework core,
asserts, fluent chain), `std.os.testing` (process matchers), and
`std.http.client.httptest` (HTTP matchers, `within`/`without`, `eventually`).
`aeocha.ae` is a thin compatibility facade forwarding to those modules, so
existing `import aeocha` code keeps working unchanged; new projects can
`import std.spec` directly. What only Aeocha has: mutation testing
(`contrib/mutate`). Structured `version=1` test reports (used by
[aeb](https://github.com/aether-lang-org/aeb) and `contrib/mutate`) come from
`std.spec`'s documented env-file transport — set `AE_SPEC_FORMAT=aeocha` and
`AE_SPEC_REPORT=<path>`. See [deprecation_notice.md](deprecation_notice.md).

```aether
import aeocha
import calc

main() {
    fw = aeocha.init()

    aeocha.describe(fw, "calculator") {
        aeocha.it("adds two numbers") callback {
            aeocha.expect_int(calc.add(2, 3)).to_equal(5)
        }
    }

    aeocha.run_summary(fw)
}
```

The suite DSL follows Java's [Cuppa](https://cuppa.forgerock.org), which was
itself inspired by Mocha. The fluent assertion API resembles AssertJ, Hamcrest,
and Chai; the one-shot `within` / `without` modifiers come from FluentSelenium.

## Documentation

- [Getting started](docs/getting-started.md) — install Aeocha and run a first test
- [Core concepts](docs/concepts.md) — suites, context, hooks, failures, timing, and reporting
- [Assertions and custom matchers](docs/assertions.md) — flat, fluent, collection, and extension APIs
- [Integration testing](docs/integration-testing.md) — child processes, HTTP, and retry modifiers
- [API reference](docs/api-reference.md) — every exported type and function
- [Executable self-test](example_self_test.ae) — working examples in one source file

The documents above are the user documentation. [aeocha.ae](aeocha.ae) remains
the authoritative implementation; [LLM.md](LLM.md) and [TODO.md](TODO.md) are
maintainer notes rather than user guides.

## Requirements

- Aether **0.538.0 or newer** — the first release whose stdlib includes
  `std.spec`, `std.os.testing`, and `std.http.client.httptest`
  ([aether PR #1574](https://github.com/aether-lang-dev/aether/pull/1574)).
  No system `libpcre2-8` needed: every toolchain this facade supports has
  the vendored regex engine (aether 0.534.0+), so
  `expect_stdout_matches_regex` always works.

## Install

An Aether module search directory must contain `aeocha.ae`. Clone or vendor the
repository, then point `AETHER_LIB_DIR` at it:

```bash
git clone https://github.com/aether-lang-dev/aeocha.git /path/to/aeocha
export AETHER_LIB_DIR=/path/to/aeocha
```

`AETHER_LIB_DIR` is a PATH-style list. You can alternatively pass the directory
with `ae --lib`. Continue with the [Getting started guide](docs/getting-started.md).

## Developing Aeocha

Prefer an installed [Aether release](https://github.com/aether-lang-dev/aether/releases/latest).
If no suitable `ae` is on `PATH`, `bootstrap_aether.sh` installs a private,
versioned toolchain under `.aether/`. It tries a prebuilt release first,
compile-probes it, and falls back to building the same release from source.
The script prints the `PATH` command needed to use it.

After editing `aeocha.ae`, clear Aether's stale import cache before testing:

```bash
rm -rf ~/.aether/cache
ae run example_self_test.ae
```

Integration checks are executable shell scripts under `tests/integration/`.

## License

MIT. See [LICENSE](LICENSE).
