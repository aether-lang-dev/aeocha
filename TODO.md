# Aeocha TODO

## Refinement / Future work

3a. **Automatic `fw` threading.** Replace the explicit `fw` parameter with a per-thread "current framework" the matchers read from a module-static cell. `init()` would set it, `run_summary()` would read it, and every `expect_*` / `assert_*` matcher would lose its `fw` parameter. Tradeoff: cleaner signatures vs. inability to run two frameworks in parallel within one process.

## Pending Migrations

Once Aeocha is importable + bare-callable, migrate the existing hand-rolled `exit(1)` test files to it:

- `contrib/tinyweb/test_integration.ae`
- `contrib/tinyweb/test_inventory.ae`
- `contrib/tinyweb/test_spec.ae`
- `tests/integration/sqlite_roundtrip/probe.ae`

Each migration gets `describe`/`it` grouping, proper pass/fail counts, and shared before/after hooks.
