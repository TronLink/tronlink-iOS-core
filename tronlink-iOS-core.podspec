Pod::Spec.new do |s|
  s.name             = 'tronlink-iOS-core'
  s.version          = '1.0.7'
  s.summary          = 'tronlink-iOS-core is repo of TronLink'
  s.module_name      = 'TLCore'

  s.homepage         = 'https://github.com/TronLink/tronlink-iOS-core'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = 'tronlinkdev'
  s.source           = { :git => 'https://github.com/TronLink/tronlink-iOS-core.git', :tag => s.version.to_s }
  s.platform = :ios, '13.0'
  s.swift_versions = '4.2'

  s.source_files = 'tronlink-iOS-core/Classes/**/*.{h,m,c,swift}'
  s.preserve_paths = 'tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto/*.table'
  s.module_map = 'tronlink-iOS-core/TLCore.modulemap'

  trezor_headers = 'tronlink-iOS-core/Classes/ABI/TrezorCrypto/trezor-crypto'
  s.private_header_files = [
    "#{trezor_headers}/nem_serialize.h",
    "#{trezor_headers}/bip39_english.h",
    "#{trezor_headers}/blake2_common.h",
    "#{trezor_headers}/check_mem.h",
    "#{trezor_headers}/groestl_internal.h",
    "#{trezor_headers}/aes/aesopt.h",
    "#{trezor_headers}/aes/aestab.h",
    "#{trezor_headers}/chacha20poly1305/ecrypt-machine.h",
    "#{trezor_headers}/chacha20poly1305/ecrypt-portable.h",
    "#{trezor_headers}/chacha20poly1305/poly1305-donna-32.h",
    "#{trezor_headers}/ed25519-donna/curve25519-donna-scalarmult-base.h",
    "#{trezor_headers}/ed25519-donna/ed25519-hash-custom.h",
    "#{trezor_headers}/ed25519-donna/ed25519-hash-custom-keccak.h",
    "#{trezor_headers}/ed25519-donna/ed25519-hash-custom-sha3.h",
    "#{trezor_headers}/ed25519-donna/ed25519-keccak.h",
    "#{trezor_headers}/ed25519-donna/ed25519-sha3.h"
  ]

  trezor = "$(PODS_TARGET_SRCROOT)/#{trezor_headers}"
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => "$(inherited) \"#{trezor}\" \"#{trezor}/aes\" \"#{trezor}/chacha20poly1305\" \"#{trezor}/ed25519-donna\"",
    'OTHER_CFLAGS' => '$(inherited) -O3',
    'SWIFT_OPTIMIZATION_LEVEL[config=Debug]' => '-Owholemodule'
  }

  s.dependency 'gRPC', '1.68.1'
  s.dependency 'Protobuf', '3.29.6'
  s.dependency 'gRPC-Core', '1.68.1'
  s.dependency 'gRPC-ProtoRPC', '1.68.1'
  s.dependency 'gRPC-RxLibrary', '1.68.1'
   
   s.dependency 'FMDB', '2.7.5'

  s.dependency 'BigInt', '3.1.0'
  s.dependency 'CryptoSwift', '1.8.4'
  s.dependency 'SwiftProtobuf', '1.38.1'

  s.requires_arc = [
    'tronlink-iOS-core/Classes/gRPC/**/*.pbrpc.m',
    'tronlink-iOS-core/Classes/ABI/ObjectiveC/EthereumCrypto.m'
  ]
end
