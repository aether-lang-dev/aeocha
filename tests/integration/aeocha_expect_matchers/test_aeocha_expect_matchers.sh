#!/bin/sh
# Smoke test for the expect_* integration-shape matchers in
# aeocha (#aeocha-integration-helpers ask). Exercises both
# the process and HTTP halves end-to-end against real subprocesses
# and a plain in-process std.http fixture server.
#
# Skips on Windows — os.run_capture is POSIX-only there, and the
# test depends on /bin/echo and /bin/sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AE="ae"

if [ "$OS" = "Windows_NT" ]; then
    echo "  [SKIP] aeocha_expect_matchers: Windows (os.run_capture is POSIX-only)"
    exit 0
fi

if ! command -v "$AE" >/dev/null; then
    echo "  [SKIP] aeocha_expect_matchers: ae not built"
    exit 0
fi

if [ ! -x /bin/echo ] || [ ! -x /bin/sh ]; then
    echo "  [SKIP] aeocha_expect_matchers: /bin/echo or /bin/sh not present"
    exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# AETHER_LIB_DIR="$ROOT" points ae's module search at the repo's local
# aeocha.ae (the var `ae` actually honours; AETHER_INCLUDE_PATH is inert).
# The probe.ae itself signals failure via aeocha.run_summary → exit(1),
# so the shell test just observes the exit code.
cd "$ROOT" || exit 1
if ! AETHER_LIB_DIR="$ROOT" "$AE" run "$SCRIPT_DIR/probe.ae" >"$tmpdir/out.log" 2>&1; then
    echo "  [FAIL] aeocha_expect_matchers"
    tail -30 "$tmpdir/out.log"
    exit 1
fi

# Sanity check that all aeocha sections actually ran (probe.ae would
# also report "0 passing" with exit 0 if the describe blocks were
# skipped silently — though the framework prints "passing" line).
if ! grep -q "passing" "$tmpdir/out.log"; then
    echo "  [FAIL] aeocha_expect_matchers — no passing summary line"
    cat "$tmpdir/out.log"
    exit 1
fi

# Confirm the sections actually ran. Aeocha prints describe/it names,
# not matcher names, so look for the describe header the process
# section emits ("process matchers") plus an it() line that only the
# new matchers produce (the stderr / regex cases). If either is
# missing the describe block was skipped or silently empty.
if ! grep -q "process matchers" "$tmpdir/out.log"; then
    echo "  [FAIL] aeocha_expect_matchers — process describe header missing"
    cat "$tmpdir/out.log"
    exit 1
fi
if ! grep -q "captures child stderr separately" "$tmpdir/out.log"; then
    echo "  [FAIL] aeocha_expect_matchers — new stderr matcher it() missing"
    cat "$tmpdir/out.log"
    exit 1
fi

echo "  [PASS] aeocha_expect_matchers"
exit 0
