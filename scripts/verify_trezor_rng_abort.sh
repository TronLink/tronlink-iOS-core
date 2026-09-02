#!/bin/sh

set -u

fail() {
    printf '%s: FAIL (%s)\n' "$1" "$2" >&2
    exit 1
}

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd) || fail "healthy-sign" "cannot resolve script directory"
repository_root=$(CDPATH= cd -P "$script_dir/.." && pwd) || fail "healthy-sign" "cannot resolve repository root"
trezor_root="$repository_root/tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto"
secrandom_source="$repository_root/tronlink-iOS-core/Classes/ABI/TrezorCrypto/util/SecRandom.m"
harness_source="$repository_root/scripts/harness/trezor_rng_abort_harness.m"

temporary_directory=$(mktemp -d /private/tmp/tlcore-trezor-rng.XXXXXX) || fail "healthy-sign" "cannot create temporary directory"
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
ulimit -c 0

compiler=$(xcrun --sdk macosx -f clang 2>/dev/null) || fail "healthy-sign" "cannot locate Apple clang"
sdk_root=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null) || fail "healthy-sign" "cannot locate macOS SDK"
compile_log="$temporary_directory/compile.log"

if ! "$compiler" -O3 -DNDEBUG -std=gnu11 -mmacosx-version-min=13.0 \
    -isysroot "$sdk_root" \
    -fmodules \
    -fmodules-cache-path="$temporary_directory/module-cache" \
    -I"$trezor_root" \
    -I"$trezor_root/ed25519-donna" \
    -DSecRandomCopyBytes=tl_fake_SecRandomCopyBytes \
    -DTL_SECRANDOM_PROTOTYPE_ONLY \
    -include "$harness_source" \
    -c "$secrandom_source" \
    -o "$temporary_directory/SecRandom.o" >"$compile_log" 2>&1; then
    sed -n '1,120p' "$compile_log" >&2
    fail "healthy-sign" "SecRandom.m compilation failed"
fi

object_names=""
for source_name in trezor_rng_abort_harness.m ecdsa.c bignum.c secp256k1.c hmac.c sha2.c memzero.c; do
    if [ "$source_name" = "trezor_rng_abort_harness.m" ]; then
        source_path=$harness_source
        object_name=trezor_rng_abort_harness.o
    else
        source_path="$trezor_root/$source_name"
        object_name=${source_name%.c}.o
    fi
    object_path="$temporary_directory/$object_name"
    if ! "$compiler" -O3 -DNDEBUG -std=gnu11 -mmacosx-version-min=13.0 \
        -isysroot "$sdk_root" \
        -fmodules \
        -fmodules-cache-path="$temporary_directory/module-cache" \
        -I"$trezor_root" \
        -I"$trezor_root/ed25519-donna" \
        -c "$source_path" \
        -o "$object_path" >>"$compile_log" 2>&1; then
        sed -n '1,120p' "$compile_log" >&2
        fail "healthy-sign" "harness source compilation failed"
    fi
    object_names="$object_names $object_path"
done

harness_binary="$temporary_directory/trezor_rng_abort_harness"
if ! "$compiler" $object_names "$temporary_directory/SecRandom.o" \
    -isysroot "$sdk_root" \
    -mmacosx-version-min=13.0 \
    -Wl,-dead_strip \
    -framework Foundation \
    -framework Security \
    -o "$harness_binary" >>"$compile_log" 2>&1; then
    sed -n '1,120p' "$compile_log" >&2
    fail "healthy-sign" "harness link failed"
fi

defined_symbols="$temporary_directory/defined-symbols.txt"
undefined_symbols="$temporary_directory/undefined-symbols.txt"
if ! nm -gj "$harness_binary" >"$defined_symbols" 2>>"$compile_log" ||
   ! nm -u "$harness_binary" >"$undefined_symbols" 2>>"$compile_log"; then
    fail "healthy-sign" "cannot inspect harness RNG binding"
fi
if ! LC_ALL=C grep -E '^_tl_fake_SecRandomCopyBytes$' "$defined_symbols" >/dev/null ||
   LC_ALL=C grep -E ' _SecRandomCopyBytes$' "$undefined_symbols" >/dev/null; then
    fail "healthy-sign" "SecRandom.m is not bound exclusively to the fake RNG"
fi

if ! "$harness_binary" --verify-timeout-supervision >/dev/null 2>&1; then
    fail "healthy-sign" "child timeout supervision self-test failed"
fi

if ! "$harness_binary" --expect-exit-zero healthy-sign >/dev/null 2>&1; then
    fail "healthy-sign" "supervised child did not exit zero with the fixed signature"
fi
printf 'healthy-sign: PASS\n'

for result_name in rng-failure-sign rng-failure-public-key rng-failure-recovery; do
    if ! "$harness_binary" --expect-sigabrt "$result_name" >/dev/null 2>&1; then
        fail "$result_name" "child did not terminate with SIGABRT"
    fi
    printf '%s: PASS (SIGABRT)\n' "$result_name"
done
