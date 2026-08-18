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

  s.source_files = 'tronlink-iOS-core/Classes/**/*'

  s.dependency 'gRPC', '1.68.1'
  s.dependency 'Protobuf', '3.29.6'
  s.dependency 'gRPC-Core', '1.68.1'
  s.dependency 'gRPC-ProtoRPC', '1.68.1'
  s.dependency 'gRPC-RxLibrary', '1.68.1'
   
   s.dependency 'TronWalletWeb3Swift', '1.1.2'
   s.dependency 'TronWalletKeystore', '1.0.5'
   s.dependency 'FMDB', '2.7.5'
   
   s.requires_arc = false
   # Generated *.pbobjc.m must stay MRC; only the RPC layer is ARC.
   # CocoaPods expands this pattern from the pod root, whereas Dir[] here would
   # resolve against the installing project's CWD and silently yield [].
   # covers *.pbrpc.m only — a hand-written ARC .m needs adding here.
   s.requires_arc = 'tronlink-iOS-core/Classes/gRPC/**/*.pbrpc.m'
end
