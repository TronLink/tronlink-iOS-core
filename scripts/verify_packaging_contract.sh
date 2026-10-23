#!/bin/sh

set -u

fail() {
    printf '%s: FAIL (%s)\n' "$1" "$2" >&2
    exit 1
}

pass() {
    printf '%s: PASS\n' "$1"
}

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd) || fail "repository-root" "cannot resolve script directory"
repository_root=$(CDPATH= cd -P "$script_dir/.." && pwd) || fail "repository-root" "cannot resolve repository root"
podspec="$repository_root/tronlink-iOS-core.podspec"
umbrella_header="$repository_root/tronlink-iOS-core/Classes/TLCore-umbrella.h"
spec_json=$(mktemp /private/tmp/tlcore-packaging-contract.XXXXXX) || fail "podspec-contract" "cannot create temporary file"
trap 'rm -f "$spec_json"' EXIT HUP INT TERM

if ! pod ipc spec "$podspec" >"$spec_json"; then
    fail "podspec-contract" "pod ipc spec failed"
fi

if ! ruby -rjson -e '
spec = JSON.parse(File.read(ARGV.fetch(0)))
frameworks = Array(spec["frameworks"])
abort "Security framework is missing" unless frameworks.include?("Security")

preserved = Array(spec["preserve_paths"])
required = [
  "tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto/*.table",
  "tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto/LICENSE",
  "ThirdPartyLicenses/*"
]
missing = required - preserved
abort "missing preserve_paths: #{missing.join(", ")}" unless missing.empty?
' "$spec_json"; then
    fail "podspec-contract" "Security or license paths are missing"
fi
pass "podspec-contract"

if grep -F '#import <UIKit/UIKit.h>' "$umbrella_header" >/dev/null 2>&1; then
    fail "umbrella-contract" "UIKit must not be imported"
fi

for required_line in \
    '#ifdef __OBJC__' \
    '#import <Foundation/Foundation.h>' \
    '#define FOUNDATION_EXPORT extern "C"' \
    '#define FOUNDATION_EXPORT extern' \
    '#import "Api.pbrpc.h"' \
    '#import "EthereumCrypto.h"' \
    '#import "TrezorCrypto.h"'; do
    if ! grep -F "$required_line" "$umbrella_header" >/dev/null 2>&1; then
        fail "umbrella-contract" "missing $required_line"
    fi
done
pass "umbrella-contract"

for required_path in \
    "$repository_root/tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto/LICENSE" \
    "$repository_root/ThirdPartyLicenses/TronWalletABI-LICENSE" \
    "$repository_root/ThirdPartyLicenses/TronWalletKeystore-LICENSE" \
    "$repository_root/ThirdPartyLicenses/TronWalletWeb3Swift-LICENSE" \
    "$repository_root/ThirdPartyLicenses/trezor-crypto-LICENSE"; do
    if [ ! -f "$required_path" ]; then
        fail "license-files" "missing $required_path"
    fi
done
pass "license-files"
pass "packaging-contract"
