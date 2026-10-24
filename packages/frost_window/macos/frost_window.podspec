Pod::Spec.new do |s|
  s.name             = 'frost_window'
  s.version          = '0.2.0'
  s.summary          = 'Native desktop window integration for Frost.'
  s.description      = 'Integrated Flutter title regions with native AppKit window controls.'
  s.homepage         = 'https://github.com/normalllll/frost_ui'
  s.license          = { :type => 'GPL-3.0', :file => '../LICENSE' }
  s.author           = { 'normalllll' => 'https://github.com/normalllll' }
  s.source           = { :path => '.' }
  s.source_files     = 'frost_window/Sources/frost_window/**/*.swift'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
