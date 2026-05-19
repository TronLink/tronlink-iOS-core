Pod::Spec.new do |s|
  s.name             = 'tronlink-iOS-core'
  s.version          = '1.0.5'
  s.summary          = 'tronlink-iOS-core is repo of TronLink'
  s.module_name      = 'TLCore'

  s.homepage         = 'https://github.com/TronLink/tronlink-iOS-core'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = 'tronlinkdev'
  s.source           = { :git => 'https://github.com/TronLink/tronlink-iOS-core.git', :tag => s.version.to_s }
  s.platform = :ios, '13.0'
  s.swift_versions = '4.2'

  s.source_files = 'tronlink-iOS-core/Classes/**/*'

  s.dependency 'gRPC', '1.68.1'
  s.dependency 'Protobuf', '3.29.6'
  s.dependency 'gRPC-Core', '1.68.1'
  s.dependency 'gRPC-ProtoRPC', '1.68.1'
  s.dependency 'gRPC-RxLibrary', '1.68.1'
   
   s.dependency 'TronWalletWeb3Swift', '1.1.1'
   s.dependency 'TronWalletKeystore', '1.0.4'
   s.dependency 'FMDB', '2.7.5'
   
   s.requires_arc = false
   grpc_arc_files = Dir['tronlink-iOS-core/Classes/gRPC/**/*.m']
   grpc_mrc_files = [
      'tronlink-iOS-core/Classes/gRPC/api/*.pbobjc.m',
      'tronlink-iOS-core/Classes/gRPC/google/protobuf/*.pbobjc.m',
      'tronlink-iOS-core/Classes/gRPC/google/api/Annotations.pbobjc.m',
      'tronlink-iOS-core/Classes/gRPC/core/Tron.pbobjc.m',
      'tronlink-iOS-core/Classes/gRPC/core/contract/SmartContract.pbobjc.m',
      'tronlink-iOS-core/Classes/gRPC/core/contract/Common.pbobjc.m'
   ].flat_map { |pattern| Dir[pattern] }
   s.requires_arc = grpc_arc_files - grpc_mrc_files
end
