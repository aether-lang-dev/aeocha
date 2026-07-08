#!/bin/sh
# Regression test for the contrib/mutate mutation-testing driver.
#
# Runs mutate.ae against a deterministic fixture (fixture/sut.ae +
# sut_test.ae) where exactly two operator sites exist:
#   - `add` is tested      -> ADD->SUB mutant KILLED
#   - `mul` is NOT tested   -> MUL->DIV mutant SURVIVES
# so the run must report exactly "1/2 ... 50%" with a MUL->DIV survivor.
#
# Asserts four things:
#   1. baseline (unmutated suite) passes,
#   2. the exact mutation score line,
#   3. the expected survivor is listed,
#   4. the SUT is restored byte-identical (md5 before == after) — the
#      safety-critical property; a driver that corrupts source is worse
#      than no driver.
#
# POSIX-only (the driver shells out via rm/ae and the harnesses assume
# /bin/sh); skipped where `ae` is unavailable.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AE="ae"
SUT="$SCRIPT_DIR/fixture/sut.ae"
TEST="$SCRIPT_DIR/fixture/sut_test.ae"

if [ "$OS" = "Windows_NT" ]; then
    echo "  [SKIP] aeocha_mutation: driver shells out via POSIX rm/ae"
    exit 0
fi

if ! command -v "$AE" >/dev/null; then
    echo "  [SKIP] aeocha_mutation: ae not built"
    exit 0
fi

if ! command -v md5sum >/dev/null; then
    MD5="cksum"      # fallback; any stable hash works for before==after
else
    MD5="md5sum"
fi

cd "$ROOT" || exit 1

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
    echo "  [FAIL] aeocha_mutation — $1"
    [ -f "$TMPDIR/out.log" ] && tail -40 "$TMPDIR/out.log" | sed 's/^/    /'
    exit 1
}

# Hash the SUT before the run (property 4).
SUT_BEFORE="$($MD5 "$SUT" | awk '{print $1}')"

rm -rf "$HOME/.aether/cache"
# The driver resolves aeocha for its per-mutant sub-builds via the lib_dir
# it's handed ("$ROOT", its 3rd arg) → AETHER_LIB_DIR. No env var on this
# outer invocation: mutate.ae imports only std.*.
if ! "$AE" run "$ROOT/contrib/mutate/mutate.ae" -- \
        "$SUT" "$TEST" "$ROOT" >"$TMPDIR/out.log" 2>&1; then
    fail "driver exited non-zero"
fi

# Property 4 first: SUT must be unchanged regardless of outcome.
SUT_AFTER="$($MD5 "$SUT" | awk '{print $1}')"
if [ "$SUT_BEFORE" != "$SUT_AFTER" ]; then
    fail "SUT not restored (md5 $SUT_BEFORE -> $SUT_AFTER)"
fi

# Property 1: baseline passed.
grep -q "baseline: suite passes" "$TMPDIR/out.log" || fail "no baseline-pass line"

# Property 2: exact score.
grep -q "1/2 mutants killed — mutation score 50%" "$TMPDIR/out.log" \
    || fail "unexpected mutation score (wanted 1/2, 50%)"

# Property 3: the known survivor and kill are reported, each anchored to a
# source location (file:line). `mul` is on line 11, `add` on line 9.
grep -Eq "SURVIVED +sut\.ae:11 +MUL->DIV" "$TMPDIR/out.log" \
    || fail "MUL->DIV survivor not reported at sut.ae:11"
grep -Eq "killed +sut\.ae:9 +ADD->SUB" "$TMPDIR/out.log" \
    || fail "ADD->SUB not killed at sut.ae:9"

echo "  [PASS] aeocha_mutation"
exit 0
