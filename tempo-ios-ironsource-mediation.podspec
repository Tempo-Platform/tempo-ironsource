#
# Run `pod spec lint tempo-ios-ironsource-mediation.podspec' to validate the spec after any changes
#
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |spec|
  spec.name          = 'tempo-ios-ironsource-mediation'
  spec.version       = '1.2.2'
  spec.swift_version = '5.0'
  spec.author        = { 'Tempo Engineering' => 'development@tempoplatform.com' }
  spec.license       = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  spec.homepage      = 'https://www.tempoplatform.com'
  spec.readme        = 'https://github.com/Tempo-Platform/tempo-ironsource/blob/main/README.md'
  spec.source        = { :git => 'https://github.com/Tempo-Platform/tempo-ironsource.git', :tag => spec.version.to_s }
  spec.summary       = 'Tempo ironSource iOS Mediation Adapter.'
  spec.description   = <<-DESC
  Using this adapter you will be able to integrate Tempo SDK via ironSource mediation
                   DESC

  spec.platform     = :ios, '11.0'

  spec.source_files = 'tempo-ios-ironsource-mediation/*.*'

  spec.dependency 'TempoSDK', '1.2.4'
  spec.dependency 'IronSourceSDK', '~> 7.3.0'
  spec.requires_arc     = true
  spec.frameworks       = 'Foundation', 'UIKit'
  spec.static_framework = true
  spec.script_phase     = {
     :name => 'Hello ',
     :script => 'echo "Adding Custom Module Header" && touch Headers/tempo_ios_ironsource_mediation.h && echo "#import <IronSource/IronSource.h>" >> Headers/tempo_ios_ironsource_mediation.h',
     :execution_position => :after_compile
   }

  spec.pod_target_xcconfig  = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  spec.pod_target_xcconfig  = { 'PRODUCT_BUNDLE_IDENTIFIER': 'com.tempoplatform.is-adapter-sdk' }
end
