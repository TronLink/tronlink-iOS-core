#
# Be sure to run `pod lib lint tronlink-iOS-core.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'tronlink-iOS-core'
  s.version          = '0.1.0'
  s.summary          = 'tronlink-iOS-core is repo of TronLink'
  s.module_name      = 'TLCore'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/TronLink/tronlink-iOS-core'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.author           = { 'TronLink' => '' }
  s.source           = { :git => 'https://github.com/TronLink/tronlink-iOS-core.git', :tag => s.version.to_s }

  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.swift_versions = '4.2'

  s.source_files = 'tronlink-iOS-core/Classes/**/*'
  s.requires_arc = true

  # s.resource_bundles = {
  #   'TLCore' => ['TLCore/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  

  # s.xcconfig = { 'SWIFT_OBJC_BRIDGING_HEADER' => '${PODS_TARGET_SRCROOT}/TLCorePod/Classes/TronLinkCore-Bridging-Header.h' }
  # s.header_mappings_dir = 'src/include'
  # s.compiler_flags = '-DOS_OBJECT_USE_OBJC=0'

  # s.resource_bundles = {
  #   'TLCorePod' => ['TLCorePod/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  
  
   s.dependency 'gRPC', '1.49.0'
   s.dependency 'Protobuf', '3.22.0'
   s.dependency 'gRPC-Core', '1.49.0'
   s.dependency 'gRPC-ProtoRPC', '1.49.0'
   s.dependency 'gRPC-RxLibrary', '1.49.0'
   s.dependency '!ProtoCompiler', '3.21.5'
   s.dependency '!ProtoCompiler-gRPCPlugin', '1.49.0'
   
   s.dependency 'TronWalletWeb3Swift'
   s.dependency 'TronWalletABI'
   s.dependency 'TronWalletKeystore'

   s.subspec 'no-arc' do |sp|
       sp.source_files  = "tronlink-iOS-core/Classes/gRPC/core/contract/SmartContract.pbobjc.{h,m}",
       "tronlink-iOS-core/Classes/gRPC/google/api/Annotations.pbobjc.{h,m}",
       "tronlink-iOS-core/Classes/gRPC/core/Tron.pbobjc.{h,m}",
       "tronlink-iOS-core/Classes/gRPC/core/contract/Common.pbobjc.{h,m}",
       "tronlink-iOS-core/Classes/gRPC/api/Zksnark.pbobjc.{h,m}",
       "tronlink-iOS-core/Classes/gRPC/google/protobuf/Descriptor.pbobjc.{h,m}",
       "tronlink-iOS-core/Classes/gRPC/api/Api_Tron.pbobjc.{h,m}"
       sp.requires_arc = false
   end

end