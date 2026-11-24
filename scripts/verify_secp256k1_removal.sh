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
temporary_directory=$(mktemp -d /private/tmp/tlcore-secp-boundary.XXXXXX) || fail "source-boundary" "cannot create temporary directory"
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM

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

license_paths="$temporary_directory/license-paths.txt"
if ! find "$licenses_root" \( -name '*secp256k1-wallet*' -o -path '*Classes/Secp256k1*' \) -print >"$license_paths"; then
    fail "source-boundary" "cannot enumerate ThirdPartyLicenses paths"
fi
if [ -s "$license_paths" ]; then
    fail "source-boundary" "forbidden path in ThirdPartyLicenses"
fi

pass "source-boundary"

if ! architectures=$(lipo -archs "$binary" 2>/dev/null); then
    fail "artifact-boundary" "lipo cannot enumerate supplied binary architectures"
fi
if [ -z "$architectures" ]; then
    fail "artifact-boundary" "supplied binary has no architectures"
fi

for architecture in $architectures; do
    case "$architecture" in
        ''|*[!A-Za-z0-9_]*)
            fail "artifact-boundary" "invalid architecture reported by lipo: $architecture"
            ;;
    esac

    symbols="$temporary_directory/symbols-$architecture.txt"
    if ! nm -arch "$architecture" -gjU "$binary" >"$symbols" 2>/dev/null; then
        fail "artifact-boundary" "nm cannot scan architecture $architecture"
    fi

    if LC_ALL=C grep -E '^_?(secp256k1_context|secp256k1_ec_|secp256k1_ecdsa_)' "$symbols" >/dev/null; then
        fail "artifact-old-symbols" "embedded libsecp256k1 symbol remains in architecture $architecture"
    else
        grep_status=$?
        if [ "$grep_status" -ne 1 ]; then
            fail "artifact-boundary" "cannot scan forbidden symbols in architecture $architecture"
        fi
    fi

    # Archive members may retain private externs. A linked dylib can also
    # localize or strip them. Only externally visible definitions form its API.
    detailed_symbols="$temporary_directory/details-$architecture.txt"
    if ! nm -arch "$architecture" -mU "$binary" >"$detailed_symbols" 2>/dev/null; then
        fail "artifact-trezor-symbols" "cannot inspect visibility for $architecture"
    fi
    exports="$temporary_directory/exports-$architecture.txt"
    awk '/ external / && !/private external/ { print $NF }' "$detailed_symbols" >"$exports" ||
        fail "artifact-trezor-symbols" "cannot read visibility for $architecture"
    if ! grep -Fx '_mnemonic_wordlist' "$exports" >/dev/null; then
        fail "artifact-trezor-symbols" "missing public word list for $architecture"
    fi
    if grep -E '^_(hdnode_|ed25519_|ecdh_multiply$|ecdsa_|expand256_modm|pbkdf2_hmac_|aes_|(x?chacha20poly1305|rfc7539)_|random32$)' "$exports" >/dev/null; then
        fail "artifact-trezor-symbols" "internal Trezor API exported by $architecture"
    fi
done

pass "artifact-old-symbols"

pass "artifact-trezor-symbols"
pass "secp256k1-removal"
