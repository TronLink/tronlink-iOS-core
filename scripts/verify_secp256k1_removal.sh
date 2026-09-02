#!/bin/sh

set -u

fail() {
    printf '%s: FAIL (%s)\n' "$1" "$2" >&2
    exit 1
}

pass() {
    printf '%s: PASS\n' "$1"
}

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    fail "binary-argument" "expected one regular TLCore binary"
fi

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd) || fail "repository-root" "cannot resolve script directory"
repository_root=$(CDPATH= cd -P "$script_dir/.." && pwd) || fail "repository-root" "cannot resolve repository root"
binary=$1
classes_root="$repository_root/tronlink-iOS-core/Classes"
podspec="$repository_root/tronlink-iOS-core.podspec"
umbrella_header="$classes_root/TLCore-umbrella.h"
licenses_root="$repository_root/ThirdPartyLicenses"
forbidden_pattern='secp256k1-wallet|Classes/Secp256k1'

if [ -e "$classes_root/Secp256k1" ]; then
    fail "source-boundary" "tronlink-iOS-core/Classes/Secp256k1 still exists"
fi

for required_path in "$podspec" "$umbrella_header" "$licenses_root" "$classes_root"; do
    if [ ! -e "$required_path" ]; then
        fail "source-boundary" "required scan input is missing: $required_path"
    fi
done

for source_file in "$podspec" "$umbrella_header"; do
    if LC_ALL=C grep -E -n "$forbidden_pattern" "$source_file" >/dev/null 2>&1; then
        fail "source-boundary" "forbidden reference in $source_file"
    else
        grep_status=$?
        if [ "$grep_status" -ne 1 ]; then
            fail "source-boundary" "cannot scan $source_file"
        fi
    fi
done

if LC_ALL=C grep -R -E -n --include='*.swift' "$forbidden_pattern" "$classes_root" >/dev/null 2>&1; then
    fail "source-boundary" "forbidden reference in current Swift sources"
else
    grep_status=$?
    if [ "$grep_status" -ne 1 ]; then
        fail "source-boundary" "cannot scan current Swift sources"
    fi
fi

if LC_ALL=C grep -R -E -n "$forbidden_pattern" "$licenses_root" >/dev/null 2>&1; then
    fail "source-boundary" "forbidden reference in ThirdPartyLicenses"
else
    grep_status=$?
    if [ "$grep_status" -ne 1 ]; then
        fail "source-boundary" "cannot scan ThirdPartyLicenses"
    fi
fi

if find "$licenses_root" \( -name '*secp256k1-wallet*' -o -path '*Classes/Secp256k1*' \) -print | grep -q .; then
    fail "source-boundary" "forbidden path in ThirdPartyLicenses"
fi

pass "source-boundary"

temporary_directory=$(mktemp -d /private/tmp/tlcore-secp-boundary.XXXXXX) || fail "artifact-boundary" "cannot create temporary directory"
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
symbols="$temporary_directory/symbols.txt"

if ! nm -gjU "$binary" >"$symbols" 2>/dev/null; then
    fail "artifact-boundary" "nm cannot read supplied binary"
fi

if LC_ALL=C grep -E '^_?(secp256k1_context|secp256k1_ec_|secp256k1_ecdsa_)' "$symbols" >/dev/null; then
    fail "artifact-old-symbols" "embedded libsecp256k1 symbol remains"
fi

pass "artifact-old-symbols"

if ! LC_ALL=C grep -E '^_ecdsa_' "$symbols" >/dev/null; then
    fail "artifact-trezor-symbols" "missing Trezor _ecdsa_* symbols"
fi

# Trezor's bip32.c exports its public API with the hdnode_ prefix.
if ! LC_ALL=C grep -E '^_hdnode_' "$symbols" >/dev/null; then
    fail "artifact-trezor-symbols" "missing Trezor BIP32 _hdnode_* symbols"
fi

if ! LC_ALL=C grep -E '^_random32$' "$symbols" >/dev/null; then
    fail "artifact-trezor-symbols" "missing Trezor _random32 symbol"
fi

pass "artifact-trezor-symbols"
pass "secp256k1-removal"
