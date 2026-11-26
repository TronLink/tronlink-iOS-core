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
  "tronlink-iOS-core/Classes/ABI/TrezorCrypto/Internal/module.modulemap",
  "tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto/*.table",
  "tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto/LICENSE",
  "ThirdPartyLicenses/*"
]
missing = required - preserved
abort "missing preserve_paths: #{missing.join(", ")}" unless missing.empty?

root = File.dirname(File.expand_path(ARGV.fetch(1)))
expand = ->(patterns) { Array(patterns).flat_map { |p| Dir.glob(p, base: root) }.sort }
api = expand.call(spec.fetch("public_header_files"))
c_headers = Dir.glob("tronlink-iOS-core/Classes/ABI/TrezorCrypto/**/*.h", base: root).sort
trezor = spec.fetch("subspecs").find { |s| s["name"] == "Trezor" }
abort "Trezor public header leak" unless (api & c_headers).empty?
abort "missing public wordlist" unless api.any? { |p| p.end_with?("/TLMnemonicWordlist.h") }
abort "missing project-only Trezor headers" unless expand.call(trezor.fetch("project_header_files")) == c_headers
abort "missing Trezor visibility flag" unless Array(trezor["compiler_flags"]).include?("-fvisibility=$(TLCORE_TREZOR_VISIBILITY)")
abort "Trezor symbols must be hidden" unless spec.fetch("pod_target_xcconfig")["TLCORE_TREZOR_VISIBILITY"] == "hidden"
' "$spec_json" "$podspec"; then
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
    '#import "TLMnemonicWordlist.h"'; do
    if ! grep -F "$required_line" "$umbrella_header" >/dev/null 2>&1; then
        fail "umbrella-contract" "missing $required_line"
    fi
done
if grep -F 'TrezorCrypto.h' "$umbrella_header" >/dev/null; then
    fail "umbrella-contract" "TrezorCrypto.h is internal"
fi
pass "umbrella-contract"

# Exercise the same symbol check used for a built archive or dylib.
export_check="$script_dir/check_trezor_exports.awk"
wordlist='00000010 (__TEXT,__text) external _mnemonic_wordlist'
private_seed='00000020 (__TEXT,__text) private external _mnemonic_to_seed'
if ! printf '%s\n' "$wordlist" "$private_seed" | awk -f "$export_check"; then
    fail "trezor-export-contract" "public word list with private helpers should pass"
fi
if printf '%s\n' "$private_seed" | awk -f "$export_check" >/dev/null; then
    fail "trezor-export-contract" "missing public word list should fail"
fi
for symbol in mnemonic_to_seed mnemonic_to_entropy mnemonic_check mnemonic_wordlist_copy hdnode_from_seed; do
    if printf '%s\n' "$wordlist" "00000020 (__TEXT,__text) external _$symbol" | awk -f "$export_check" >/dev/null; then
        fail "trezor-export-contract" "unexpected export _$symbol should fail"
    fi
done
pass "trezor-export-contract"

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
