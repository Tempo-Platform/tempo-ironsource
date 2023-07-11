Pod::Spec.new do |spec|

  spec.name         = "tempo-ios-ironsource-mediation"
  spec.version      = "1.0.5"
  spec.summary      = "Tempo ironSource iOS Mediation Adapter."

  spec.description  = <<-DESC
  Using this adapter you will be able to integrate Tempo SDK via ironSource mediation
                   DESC

  spec.homepage     = "https://www.tempoplatform.com"
  spec.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  spec.author       = { "Stephen" => "stephen@tempoplatform.com" }
  
  spec.platform     = :ios, "11.0"
  spec.source       = { :git => "https://github.com/Tempo-Platform/tempo-ironsource.git", :tag => spec.version.to_s }
  
  spec.frameworks   = "Foundation", "UIKit"
  spec.requires_arc = true
  spec.static_framework = true
  spec.swift_version = '5.0'

  spec.dependency "TempoSDK", "1.0.7"
  spec.dependency "IronSourceSDK", "~> 7.3.0"
  
  spec.source_files = "tempo-ios-ironsource-mediation/*.*"
  spec.script_phase = {
     :name => 'Hello ',
     :script => "echo 'Adding Custom Module Header' && touch Headers/tempo_ios_ironsource_mediation.h && echo '#import <IronSource/IronSource.h>' >> Headers/tempo_ios_ironsource_mediation.h",
     :execution_position => :after_compile
   }
   

   
  spec.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  spec.pod_target_xcconfig = { 'PRODUCT_BUNDLE_IDENTIFIER': 'com.tempoplatform.is-adapter-sdk' }
  
end
