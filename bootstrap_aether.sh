#!/usr/bin/env bash
# Install a private Aether toolchain for developing Aeocha.
#
# Normal Aeocha users should install an Aether release directly. This helper is
# for a checkout whose developer has no suitable `ae` on PATH. It follows the
# same release-first strategy as aeb: try a prebuilt release, compile-probe it,
# then fall back to Aether's source installer when the platform has no usable
# binary.
#
# Knobs:
#   AETHER_VERSION=X.Y.Z    install this release (default: latest GitHub release)
#   AEOCHA_AETHER_SOURCE=1 skip the prebuilt and build the release from source
#   AEOCHA_AETHER_DIR=...  cache root (default: <this checkout>/.aether)

set -eu

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE_DIR="${AEOCHA_AETHER_DIR:-$ROOT_DIR/.aether}"
REPO="aether-lang-dev/aether"

say() { printf 'aeocha-bootstrap: %s\n' "$*"; }
die() { printf 'aeocha-bootstrap: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have curl || die "curl is required"
have tar || die "tar is required"

# Aeocha deliberately tracks current Aether while it has no compatibility-bound
# user community. Keep this product floor aligned with README.md.
version_number() {
    value=$(printf '%s' "${1:-}" | sed -e 's/^[Vv]//' -e 's/[^0-9.].*$//')
    major=$(printf '%s' "$value" | sed -e 's/\..*$//')
    minor=$(printf '%s' "$value" | sed -e 's/^[0-9]*\.//' -e 's/\..*$//')
    case "$major" in ''|*[!0-9]*) major=0 ;; esac
    case "$minor" in ''|*[!0-9]*) minor=0 ;; esac
    printf '%s' "$((major * 1000 + minor))"
}

if have ae; then
    installed=$(ae version 2>/dev/null | head -1 | sed -e 's/^ae //' -e 's/ .*$//' || true)
    if [ "$(version_number "$installed")" -ge "$(version_number 0.494.0)" ]; then
        say "using ae ${installed} already on PATH ($(command -v ae))"
        exit 0
    fi
    say "ae ${installed:-unknown} on PATH is older than the required 0.494.0"
fi

version="${AETHER_VERSION:-}"
if [ -z "$version" ]; then
    version=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([0-9][0-9.]*\)".*/\1/p' \
        | head -1)
fi
[ -n "$version" ] || die "could not resolve the latest Aether release; set AETHER_VERSION"
version=$(printf '%s' "$version" | sed 's/^[Vv]//')
case "$version" in
    ''|*[!0-9.]*) die "invalid AETHER_VERSION '$version' (expected X.Y.Z)" ;;
esac
if [ "$(version_number "$version")" -lt "$(version_number 0.494.0)" ]; then
    die "AETHER_VERSION=$version is below Aeocha's required 0.494.0"
fi

install_dir="$CACHE_DIR/toolchains/aether-$version"
if [ -x "$install_dir/bin/ae" ]; then
    say "using cached Aether $version"
    say "run: export PATH=\"$install_dir/bin:\$PATH\""
    exit 0
fi
# A previous interrupted install may have left this exact version directory
# incomplete. It is private bootstrap state and safe to replace.
if [ -e "$install_dir" ]; then rm -rf "$install_dir"; fi

mkdir -p "$CACHE_DIR/toolchains"
tmp_dir=$(mktemp -d "$CACHE_DIR/toolchains/.install-$version.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

os=""
archive_ext="tar.gz"
case "$(uname -s)" in
    Linux) os="linux" ;;
    Darwin) os="macos" ;;
    FreeBSD) os="freebsd" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows"; archive_ext="zip" ;;
esac

arch=""
case "$(uname -m)" in
    x86_64|amd64) arch="x86_64" ;;
    arm64|aarch64) arch="arm64" ;;
esac

asset=""
case "$os-$arch" in
    linux-x86_64|macos-arm64|macos-x86_64|windows-x86_64|freebsd-x86_64)
        asset="aether-$version-$os-$arch.$archive_ext" ;;
esac

installed_ok=0
if [ -n "$asset" ] && [ "${AEOCHA_AETHER_SOURCE:-}" != "1" ]; then
    url="https://github.com/$REPO/releases/download/v$version/$asset"
    say "trying prebuilt $asset"
    if curl -fsSL "$url" -o "$tmp_dir/$asset"; then
        extract_ok=0
        if [ "$archive_ext" = "zip" ]; then
            if have unzip && (cd "$tmp_dir" && unzip -q "$asset"); then extract_ok=1; fi
        else
            if tar xzf "$tmp_dir/$asset" -C "$tmp_dir"; then extract_ok=1; fi
        fi
        rm -f "$tmp_dir/$asset"

        # `version` alone cannot detect a binary whose dynamic-library floor is
        # incompatible with the host. Compile and run a tiny program instead.
        if [ "$extract_ok" = "1" ] && [ -x "$tmp_dir/bin/ae" ]; then
            printf 'main() { println("aeocha_probe_ok")\n return 0 }\n' >"$tmp_dir/_probe.ae"
            if "$tmp_dir/bin/ae" run "$tmp_dir/_probe.ae" 2>/dev/null \
                | grep -q aeocha_probe_ok; then
                rm -f "$tmp_dir/_probe.ae"
                mv "$tmp_dir" "$install_dir"
                trap - EXIT INT TERM
                installed_ok=1
                say "Aether $version ready from the prebuilt release"
            fi
        fi
    fi
fi

if [ "$installed_ok" = "0" ]; then
    say "no usable prebuilt for $(uname -s)/$(uname -m); building release v$version from source"
    have make || die "GNU make is required for the source fallback"
    compiler="${CC:-cc}"
    have "$compiler" || die "a C compiler ('$compiler') is required for the source fallback"
    get_script="$tmp_dir/get.sh"
    curl -fsSL "https://raw.githubusercontent.com/$REPO/v$version/get.sh" -o "$get_script"
    AETHER_REF="v$version" PREFIX="$install_dir" sh "$get_script"
    [ -x "$install_dir/bin/ae" ] || die "source install completed without $install_dir/bin/ae"
fi

say "run: export PATH=\"$install_dir/bin:\$PATH\""
say "then verify with: ae version"
