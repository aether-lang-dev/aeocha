# A Cucumber-shaped acceptance framework for Aether

Status: design proposal, not an implementation commitment.

## The short answer

The Cucumber team would probably not add `given`, `when`, and `then` aliases to
Aeocha. That would reproduce the visible vocabulary while missing Cucumber's
actual product: executable examples written in Gherkin, kept separate from the
code that implements their steps, with precise discovery, filtering, lifecycle,
status, and reporting semantics.

For Aether, they would likely make a small native runner with four deliberate
boundaries:

```text
.feature files
      │
      ▼
 Gherkin parser ──► compiled scenarios (pickles)
                          │
Aether glue registry ─────┤
                          ▼
                  scenario executor
                          │
                          ▼
              Cucumber Messages (NDJSON)
                    │             │
                    ▼             ▼
              console/JUnit      aeb
```

Aeocha remains the code-facing BDD test framework. The new runner is the
example-facing acceptance framework. They should share assertions and
integration probes, but not pretend to be the same execution model.

Working name in this document: **Cucumber for Aether**. Do not choose a product
name containing Cucumber, or imply official compatibility, without resolving
the project's naming and trademark expectations. `aether-gherkin` is a safer
repository/module name during incubation.

## Product intent

The primary use case is a repository where examples are useful to people who do
not want to read Aether source:

```gherkin
Feature: Withdrawal
  Rule: An account cannot be overdrawn

    Scenario: Refuse a withdrawal above the balance
      Given an account with a balance of 20
      When the owner withdraws 25
      Then the withdrawal is refused
      And the balance is 20
```

The Aether glue connects that language to the system:

```aether
import aether_gherkin

register_steps(registry: ptr) {
    aether_gherkin.given(registry, "an account with a balance of {int}") callback {
        world = aether_gherkin.world()
        balance = aether_gherkin.arg_int(0)
        account_create(world, balance)
    }

    aether_gherkin.when(registry, "the owner withdraws {int}") callback {
        account_withdraw(aether_gherkin.world(), aether_gherkin.arg_int(0))
    }

    aether_gherkin.then(registry, "the withdrawal is refused") callback {
        expect_withdrawal_refused(aether_gherkin.world())
    }

    aether_gherkin.then(registry, "the balance is {int}") callback {
        aether_gherkin.assert_eq(account_balance(aether_gherkin.world()),
                                 aether_gherkin.arg_int(0), "account balance")
    }
}
```

The spelling is illustrative. A spike must prove the callback and context shape
before it becomes public API.

## Principles the design should preserve

### Gherkin is not decoration

The `.feature` file is a parsed source document with locations, descriptions,
tags, Rules, Backgrounds, Scenario Outlines, Examples, Doc Strings, and Data
Tables. It must not be implemented as a line-oriented search for `Given` and
friends.

### Keywords describe, expressions bind

`Given`, `When`, and `Then` communicate narrative intent. They do not create
separate step-definition namespaces. The text after the keyword is matched
against one registry, so identical text cannot mean three different things just
because its keyword changed.

### Each scenario owns its state

No state leaks between scenarios. A World factory creates a new scenario state
object; hooks and steps for that scenario receive the same World. Parallel
execution must not turn ambient state into cross-scenario state.

### Ambiguity is an error

Zero matches means undefined. More than one match means ambiguous. Cucumber
must never select the first registered step and silently continue.

### Events are the stable integration surface

Console output is a formatter, not the runner's internal truth. Execution emits
Cucumber Messages-compatible envelopes so pretty output, JUnit, JSON, rerun
files, IDEs, and `aeb` can consume the same event stream.

### Compatibility claims are earned by corpora

“Gherkin-compatible” and “Cucumber Expressions-compatible” require running the
upstream parser and expression acceptance data. Until then, call a subset a
subset and version it explicitly.

## Relationship with Aeocha

**This is not an Aeocha mode, frontend, plugin, or alternate syntax.** It is a
different test product with a different source model, lifecycle, status model,
reporting protocol, and likely a sibling repository. A user must be able to
install and run it without installing or initialising Aeocha.

The projects may cooperate at a narrow, optional seam:

- Extract generally useful assertion and integration primitives into a neutral
  third module only if both projects genuinely benefit. Neither runner owns
  that module.
- Offer an optional Aeocha assertion adapter if it can be done without sharing
  Aeocha's framework context. Do not make it the default documentation path.
- The Cucumber runner may independently choose soft assertions *inside a step*:
  several checks can report, and the step becomes failed when control returns
  to the runner. That is a runner policy, not inherited Aeocha semantics.
- Do not implement scenarios by mechanically wrapping each one in
  `aeocha.it`. Cucumber has additional statuses and stop/skip rules that do not
  map cleanly onto Aeocha's PASS/FAIL counter.
- Do not reuse Aeocha's single ambient framework cell as the scenario World.
  That would prevent safe concurrency and make glue state depend on whichever
  framework called `init()` last.

If a neutral matcher module emerges, its failure sink is supplied by the
caller: Aeocha records an `it` failure, while the Cucumber runner records a step
failure. Until Aether has the right callable/interface shape, duplicated small
assertion primitives are safer than coupling the runners' global state.

## Proposed package shape

```text
aether-gherkin/
├── bin/
│   └── aether-gherkin              # trampoline or installed executable
├── src/
│   ├── ast.ae                      # parsed Gherkin document model
│   ├── parser.ae                   # grammar + source locations
│   ├── pickle.ae                   # Background/Outline expansion
│   ├── expressions.ae              # Cucumber Expressions
│   ├── registry.ae                 # glue, hooks, parameter types
│   ├── runner.ae                   # selection and execution
│   ├── world.ae                    # per-scenario state lifecycle
│   ├── messages.ae                 # envelope/event construction
│   └── formatters/
│       ├── progress.ae
│       ├── pretty.ae
│       ├── junit.ae
│       └── rerun.ae
├── features/                       # framework acceptance suite
├── testdata/                       # pinned upstream compatibility data
└── docs/
```

Whether Aether packaging ultimately prefers one `module.ae`, an `.aea` archive,
or an `aeb` dependency is a distribution decision, not a reason to collapse the
internal boundaries.

## Runtime API sketch

The smallest explicit entry point is preferable to magic source discovery:

```aether
import aether_gherkin
import app_steps

main() {
    run = aether_gherkin.init()
    aether_gherkin.world_factory(run, new_world)
    app_steps.register(run)
    aether_gherkin.run_cli(run)
}
```

Registration should initially accept Cucumber Expressions only:

```aether
given(run, expression, callback)
when(run, expression, callback)
then(run, expression, callback)
before(run, tag_expression, callback)
after(run, tag_expression, callback)
parameter_type(run, name, regexp, transformer)
```

The three step-registration functions feed one registry. Separate names are
reader affordances.

### Callback arguments

Aether does not offer the reflection and arbitrary typed method invocation used
by Cucumber-JVM. Do not counterfeit that with a matrix of `fn0`, `fn1_int`,
`fn2_string_int` APIs.

For the first native API, callbacks should read typed values from a scenario
invocation context:

```aether
arg_count() -> int
arg_string(index: int) -> string
arg_int(index: int) -> int
arg_float(index: int) -> float
doc_string() -> string
data_table() -> ptr
world() -> ptr
```

This is less magical than Java annotations but honest, extensible, and possible
in Aether. A later compiler feature could inject a typed `StepContext` into the
trailing callback or generate typed glue at build time.

### World ownership

The runner calls `new_world()` before each scenario and an optional disposer
after its final hook. World is opaque `ptr` at the framework boundary. Glue may
wrap it with project-specific functions.

Ambient accessors such as `world()` and `arg_int()` are acceptable in the
single-scenario executor, provided parallelism uses one process per scenario or
gains genuine task-local storage. A shared module-global current World is not
safe for actor-level parallel scenarios.

## Parsing strategy

There are three plausible approaches.

### A. Native full Gherkin parser

Implement the official grammar and compile Gherkin documents into pickles in
Aether. Vendor the upstream parser test corpus and dialect data.

Advantages:

- one native executable;
- source locations and errors can be first-class;
- no runtime dependency on Node, Java, Go, or Ruby;
- the implementation exercises Aether's parser-building capabilities.

Costs:

- this is a compatibility project, not a weekend parser;
- localisation and grammar evolution require active upstream tracking;
- Data Tables, Doc Strings, escaping, comments, descriptions, and Outline
  substitution contain more edge cases than the surface syntax suggests.

This is the right destination if the project intends to say “Cucumber,” but not
necessarily the fastest spike.

### B. Canonical parser sidecar

Invoke an existing official Gherkin implementation and consume its Cucumber
Messages NDJSON output.

Advantages: fast route to correct parsing and a useful oracle for tests.

Costs: poor standalone DX, platform packaging, process startup, and a foreign
runtime or helper binary. It also makes the native runner depend on a transport
before its own execution model is proven.

This is useful as a development oracle, not the desired permanent user path.

### C. Build-time generated Aether

Have `aeb` compile `.feature` files into an Aether data module, then link that
with glue and the runner.

Advantages: no runtime parser in deployed test binaries; syntax errors appear
during the build; compiled examples can participate in build caching.

Costs: edit/run latency includes generation; direct `ae run` is less natural;
dynamic feature selection still needs metadata; generated code becomes another
surface to debug.

This is a valuable optimisation after A, not the first architecture.

### Recommendation

Use B as the oracle while building A. Add C once the native parser and message
model are stable. Do not ship a casual English-only line parser under the
Cucumber name.

## Gherkin scope

The first compatibility milestone should cover:

- one `Feature` per `.feature` file;
- free-form descriptions and comments;
- `Rule`;
- `Background` at Feature and Rule scope;
- `Scenario` / `Example`;
- `Scenario Outline` / `Scenario Template` with multiple `Examples` blocks;
- tags on Feature, Rule, Scenario, Outline, and Examples;
- `Given`, `When`, `Then`, `And`, `But`, and `*`;
- Doc Strings with indentation and optional content type;
- Data Tables with standard escaping;
- stable URI, line, and column locations on every executable node.

English is acceptable for the first executable milestone only if the AST and
keyword lookup are dialect-aware from day one. Import the official dialect data
before claiming Gherkin compatibility.

## Cucumber Expressions

Start with expressions rather than regex. They are the approachable default and
avoid making PCRE2 a mandatory dependency for ordinary suites.

Initial built-ins:

- `{int}`
- `{float}`
- `{word}`
- `{string}`
- `{}` anonymous string

Then add optional text, alternatives, escaping, custom parameter types,
snippet preference, and ambiguity rules according to the upstream acceptance
suite.

Regex step definitions may follow as an explicit API such as
`given_regex(...)`. They require `libpcre2-8`; never guess expression kind from
punctuation if Aether can make the choice explicit.

## Execution semantics

For each selected pickle:

1. Create a fresh World.
2. Emit scenario-started.
3. Run matching Before hooks from least to most specific registration scope.
4. Run Background steps, then Scenario steps.
5. Resolve each step against the complete registry.
6. If undefined, ambiguous, pending, or failed, record that status and skip the
   remaining ordinary steps.
7. Run After hooks even when a step failed, in reverse order.
8. Dispose the World.
9. Emit scenario-finished with duration and the worst status.

Statuses should be explicit, not squeezed into booleans:

```text
UNKNOWN
SKIPPED
PENDING
UNDEFINED
AMBIGUOUS
FAILED
PASSED
```

Define and test status precedence. Infrastructure errors such as an unreadable
feature file or formatter failure are run errors, distinct from failed
scenarios.

Undefined steps should print compilable Aether snippets. Snippet generation is
part of the first useful developer experience, not polish for later.

## Hooks and tags

Support `Before`, `After`, `BeforeStep`, and `AfterStep`, each optionally guarded
by a tag expression. Preserve invoke-around semantics: an `AfterStep` paired
with an entered `BeforeStep` still runs when the step fails.

Implement the standard tag-expression grammar (`and`, `or`, `not`, and
parentheses), rather than a bespoke comma convention.

CLI filtering should include:

```text
--tags EXPRESSION
--name REGEX
--location path.feature:LINE
--order defined|random
--seed N
```

Tags are selectors and hook conditions. Avoid turning every tag into a runner
configuration switch.

## Messages and formatters

Cucumber Messages NDJSON should be the canonical result stream. At minimum the
runner will need envelopes corresponding to source, parsed document, pickle,
test case, test case started, test step started/finished, attachment, and test
case finished.

Do not hand-invent a similarly named JSON schema. Generate or carefully map the
official message schema, pin its version, and add golden compatibility tests.

First formatters:

1. `progress` for terse local and CI runs;
2. `pretty` with source locations and parameter highlighting;
3. `message` for raw NDJSON interoperability;
4. `junit` for generic CI;
5. `rerun` containing failed `uri:line` selectors.

HTML should consume recorded Messages as a separate tool. Keeping it out of the
runner avoids embedding a web application in the core.

Attachments should be possible from hooks and steps:

```aether
attach_text("response", body)
attach_file("screenshot", "image/png", path)
```

The event stream records attachment metadata and content according to the
message schema.

## CLI and configuration

The direct runner should feel conventional:

```bash
aether-gherkin features/
aether-gherkin features/withdrawal.feature:12
aether-gherkin --tags '@smoke and not @slow'
aether-gherkin --format progress --format junit:build/cucumber.xml
```

Configuration belongs in a small checked-in file, tentatively
`aether-gherkin.toml`:

```toml
features = ["features"]
glue = ["features/steps"]
format = ["progress"]
strict = true
```

Avoid profiles until repeated real usage demonstrates a need. Environment
variables should override machine concerns, not become a second configuration
language.

## `aeb` integration

`aeb` should launch the runner rather than parse Gherkin itself. Two integration
levels make sense:

1. Treat the Cucumber executable as a normal test target and use its exit
   status plus JUnit output.
2. Add a Cucumber Messages-aware adapter that streams scenario and step results
   into `aeb`'s test UI without flattening them to Aeocha's v1 row format.

Do not force Cucumber's hierarchy into Aeocha's `STATUS/index/name/message`
wire rows. A Feature → Rule → Scenario → Step tree, attachments, undefined
steps, and retries deserve their native model.

An eventual `aeb` SDK could recognise:

```text
features/**/*.feature
features/steps/**/*.ae
```

and cache parser output by feature content plus parser version. That convention
should follow a working standalone runner, not precede it.

## Parallel execution

Start serial and deterministic. Then add process-level scenario workers:

- the coordinator parses, filters, orders, and assigns pickles;
- each worker process loads the same glue and executes one scenario at a time;
- workers emit Messages to the coordinator;
- the coordinator assigns event sequence IDs and formats output;
- `--order random --seed N` remains reproducible.

Process isolation fits Aether's current ambient-state realities and prevents a
failed scenario, leaked World, or long-lived actor from corrupting a sibling.
Actor-level parallelism can follow only after World, arguments, hooks, and
failure sinks are task-local rather than module-global.

## Deliberate non-goals for v1

- No attempt to make every Aeocha unit test readable as Gherkin.
- No annotations or reflection emulation.
- No dependency-injection container.
- No browser automation bundled into the core.
- No distributed execution before local process workers are correct.
- No HTML formatter inside the runner.
- No invented Gherkin extensions.
- No compatibility claim based only on happy-path examples.

## Delivery plan

### Phase 0 — feasibility spikes

Produce disposable proofs for the three risky seams:

1. **Glue invocation:** register callbacks, match an expression, expose two
   typed arguments plus World, and invoke safely across modules.
2. **Parser model:** consume a canonical Gherkin Messages fixture and represent
   Feature → Rule → Pickle → Step with source locations in Aether.
3. **Failure sink:** run two soft Aeocha-style checks inside one step, return a
   failed step result, then skip the next step while still running After.

Exit criterion: one hand-authored feature executes without generated C glue or
a hard-coded step switch.

### Phase 1 — walking skeleton

- English Scenario/Given/When/Then/And/But.
- Exact-text and `{int}` / `{string}` expressions.
- One World per scenario.
- Before/After hooks.
- Passed, failed, undefined, ambiguous, and skipped statuses.
- Progress formatter and deterministic exit codes.
- Undefined-step snippets.

Exit criterion: the framework tests itself through `.feature` files, including
all failure paths.

### Phase 2 — useful Gherkin

- Rule and Background.
- Scenario Outlines and Examples.
- Data Tables and Doc Strings.
- Tags, tag expressions, name and location filters.
- Full initial Cucumber Expressions set and custom parameter types.
- Message and JUnit formatters.

Exit criterion: upstream compatibility fixtures pass for the declared English
grammar and expression scope.

### Phase 3 — interoperability

- Official Cucumber Messages schema and golden NDJSON tests.
- `aeb` adapter.
- Attachments and rerun formatter.
- Random order with seeds.
- Process-level parallel workers.

Exit criterion: the same recorded event stream renders consistently through
progress, pretty, JUnit, and an `aeb` consumer.

### Phase 4 — compatibility breadth

- Gherkin dialect data and localisation.
- Regex step definitions.
- BeforeStep/AfterStep.
- Remaining parser and expression corpus.
- Packaging as a normal Aether dependency and installed CLI.

Exit criterion: publish an explicit compatibility matrix and only then consider
using “Cucumber-compatible” in the project description.

## Test strategy

Each layer needs its own evidence:

- parser golden tests including invalid syntax and exact locations;
- pickle tests for Background and Outline expansion;
- expression corpus tests for match values, argument conversion, ambiguity,
  and escaping;
- lifecycle traces proving hook and skip order;
- failure-path tests for undefined, ambiguous, failed, pending, hook failure,
  parse failure, and formatter failure;
- Messages golden files validated by an independent official consumer;
- end-to-end CLI tests on Linux, macOS, and Windows;
- leak and isolation tests across many scenarios and parallel workers;
- dogfood features that exercise real Aether HTTP/process applications rather
  than arithmetic alone.

Never validate the runner only through its pretty formatter. Assert the event
model first, then formatter output.

## Decisions to make before implementation

1. Is the goal genuine Cucumber interoperability, or merely a Gherkin-inspired
   Aether tool? The parser and Messages commitments differ substantially.
2. Does the first parser ship native, or does a canonical sidecar temporarily
   remain a runtime dependency?
3. Can Aether v0.494 express a safe StepContext callback directly, or should
   the first API use ambient argument accessors and process isolation?
4. Should reusable matchers be extracted from Aeocha now, or after the runner's
   failure sink has proved its shape?
5. Is this a sibling repository to Aeocha? The recommendation is yes.
6. Which official Messages schema version is pinned for the first interop
   milestone?

## Recommended first move

Create a sibling spike, not a feature branch inside Aeocha. Pin Aether 0.494+.
Use the official parser as a test oracle, implement only enough native data
model and expression matching to execute one Feature, and prove the World plus
failure-sink API before investing in a full grammar.

If that spike feels natural in Aether, proceed toward a native parser and
Messages stream. If callback invocation or isolated World state remains
contorted, stop and improve the language/runtime seam rather than fossilising a
bad public DSL.

That restraint is the most Cucumber-like choice: optimise for examples people
can trust and maintain, not for quickly acquiring the keywords.

## Cucumber references used by this plan

- [Cucumber introduction](https://cucumber.io/docs/)
- [Gherkin reference](https://cucumber.io/docs/gherkin/reference/)
- [Step definitions](https://cucumber.io/docs/cucumber/step-definitions/)
- [Cucumber Expressions](https://cucumber.io/docs/cucumber/cucumber-expressions/)
- [Cucumber hooks, tags, and statuses](https://cucumber.io/docs/cucumber/api/)
- [Reporting and formatter events](https://cucumber.io/docs/cucumber/reporting/)
