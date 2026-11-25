Pod::Spec.new do |s|
  s.name             = 'tronlink-iOS-core'
  s.version          = '2.0.2'
  s.summary          = 'tronlink-iOS-core is repo of TronLink'
  s.module_name      = 'TLCore'

  s.homepage         = 'https://github.com/TronLink/tronlink-iOS-core'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = 'tronlinkdev'
  s.source           = { :git => 'https://github.com/TronLink/tronlink-iOS-core.git', :tag => s.version.to_s }
  s.platform = :ios, '15.1'
  s.swift_versions = '4.2'
  s.framework = 'Security'

  api_headers = [
    'tronlink-iOS-core/Classes/TLCore-umbrella.h',
    'tronlink-iOS-core/Classes/ABI/ObjectiveC/*.h',
    'tronlink-iOS-core/Classes/gRPC/**/*.h'
  ]
  s.public_header_files = api_headers
  s.source_files = api_headers + [
    'tronlink-iOS-core/Classes/**/*.swift',
    'tronlink-iOS-core/Classes/{ABI/ObjectiveC,gRPC}/**/*.m'
  ]
  trezor_root = 'tronlink-iOS-core/Classes/ABI/TrezorCrypto'
  trezor_headers = "#{trezor_root}/trezor-crypto"
  s.preserve_paths = [
    "#{trezor_root}/Internal/module.modulemap",
    "#{trezor_headers}/*.table",
    "#{trezor_headers}/LICENSE",
    'ThirdPartyLicenses/*'
  ]
  s.module_map = 'tronlink-iOS-core/TLCore.modulemap'

  s.subspec 'Trezor' do |crypto|
    crypto.source_files = "#{trezor_root}/**/*.{h,c,m}"
    crypto.project_header_files = "#{trezor_root}/**/*.h"
    crypto.compiler_flags = '-fvisibility=$(TLCORE_TREZOR_VISIBILITY)'
  end

  trezor = "$(PODS_TARGET_SRCROOT)/#{trezor_headers}"
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => "$(inherited) \"#{trezor}\" \"#{trezor}/aes\" \"#{trezor}/chacha20poly1305\" \"#{trezor}/ed25519-donna\"",
    'SWIFT_INCLUDE_PATHS' => "$(inherited) \"$(PODS_TARGET_SRCROOT)/#{trezor_root}/Internal\"",
    'TLCORE_TREZOR_VISIBILITY' => 'hidden',
    'OTHER_CFLAGS' => '$(inherited) -O3',
    'SWIFT_OPTIMIZATION_LEVEL[config=Debug]' => '-Owholemodule'
  }

  s.dependency 'gRPC', '1.84.1'
  s.dependency 'Protobuf', '5.36.2'
  s.dependency 'gRPC-Core', '1.84.1'
  s.dependency 'gRPC-ProtoRPC', '1.84.1'
  s.dependency 'gRPC-RxLibrary', '1.84.1'
   
  s.dependency 'FMDB', '2.7.12'
  s.dependency 'BigInt', '5.2.0'
  s.dependency 'CryptoSwift', '1.10.0'

  s.requires_arc = [
    'tronlink-iOS-core/Classes/gRPC/**/*.pbrpc.m',
    'tronlink-iOS-core/Classes/ABI/ObjectiveC/EthereumCrypto.m'
  ]
end
