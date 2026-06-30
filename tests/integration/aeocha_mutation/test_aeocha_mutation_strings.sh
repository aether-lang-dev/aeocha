#!/bin/sh
# Regression for contrib/mutate's STRING-literal mutation + the
# operator-in-string skip (string-boundary awareness).
#
# fixture_str/sut.ae has three string literals and one of them (help)
# contains an arithmetic operator INSIDE the string ("a + b"):
#   - name()  is tested        -> STR->EMPTY killed
#   - motto() is NOT tested     -> STR->EMPTY survives
#   - help()  is NOT tested     -> STR->EMPTY survives
# and there are NO code-level arithmetic operators, so the run must be
# exactly "1/3 ... 33%" with two STR->EMPTY survivors.
#
# Asserts:
#   1. baseline passes,
#   2. exact score "1/3 ... 33%",
#   3. a STR->EMPTY survivor is reported (string mutation works),
#   4. NO ADD->SUB mutant appears — the ` + ` inside help()'s string was
#      skipped (the boundary-awareness / false-mutant fix),
#   5. SUT restored byte-identical.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AE="ae"
SUT="$SCRIPT_DIR/fixture_str/sut.ae"
TEST="$SCRIPT_DIR/fixture_str/sut_test.ae"

if [ "$OS" = "Windows_NT" ]; then
    echo "  [SKIP] aeocha_mutation_strings: driver shells out via POSIX rm/ae"
    exit 0
fi
if ! command -v "$AE" >/dev/null; then
    echo "  [SKIP] aeocha_mutation_strings: ae not built"
    exit 0
fi
if command -v md5sum >/dev/null; then MD5="md5sum"; else MD5="cksum"; fi

cd "$ROOT" || exit 1
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
    echo "  [FAIL] aeocha_mutation_strings — $1"
    [ -f "$TMPDIR/out.log" ] && tail -40 "$TMPDIR/out.log" | sed 's/^/    /'
    exit 1
}

SUT_BEFORE="$($MD5 "$SUT" | awk '{print $1}')"

rm -rf "$HOME/.aether/cache"
if ! AETHER_INCLUDE_PATH="$ROOT" "$AE" run "$ROOT/contrib/mutate/mutate.ae" -- \
        "$SUT" "$TEST" "$ROOT" >"$TMPDIR/out.log" 2>&1; then
    fail "driver exited non-zero"
fi

SUT_AFTER="$($MD5 "$SUT" | awk '{print $1}')"
[ "$SUT_BEFORE" = "$SUT_AFTER" ] || fail "SUT not restored (md5 $SUT_BEFORE -> $SUT_AFTER)"

grep -q "baseline: suite passes" "$TMPDIR/out.log" || fail "no baseline-pass line"
grep -q "1/3 mutants killed — mutation score 33%" "$TMPDIR/out.log" \
    || fail "unexpected score (wanted 1/3, 33%)"
grep -Eq "SURVIVED +STR->EMPTY" "$TMPDIR/out.log" || fail "no STR->EMPTY survivor (string mutation broken?)"
grep -Eq "killed +STR->EMPTY"   "$TMPDIR/out.log" || fail "STR->EMPTY never killed"
# The crucial boundary-awareness check: the ` + ` inside help()'s string
# must NOT have produced an operator mutant.
if grep -q "ADD->SUB" "$TMPDIR/out.log"; then
    fail "ADD->SUB appeared — operator inside a string literal was NOT skipped"
fi

echo "  [PASS] aeocha_mutation_strings"
exit 0
