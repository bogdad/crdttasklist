platform :ios, '12.0'

target 'crdttasklist' do
  use_modular_headers!
  pod 'IteratorTools', '~> 1.1.0'
  pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '1d47f57b4ae9f21d22c3fb51930ae171ac88f77c'
  pod 'SwiftyDropbox'
  pod 'SwiftNIO', '~> 2.18'
  pod 'HLClock', :git => 'https://github.com/bogdad/HLClock.git', :commit => '75a343f12c53e3fd60465ec36768f2a2b84b9131'
  inherit! :search_paths

  target 'crdttasklistTests' do
      inherit! :search_paths
      pod 'SwiftNIO', '~> 2.18'
      pod 'IteratorTools', '~> 1.1.0'
  end

  target 'crdttasklistUITests' do
      inherit! :search_paths
      pod 'IteratorTools', '~> 1.1.0'
      pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '1d47f57b4ae9f21d22c3fb51930ae171ac88f77c'
      pod 'HLClock', :git => 'https://github.com/bogdad/HLClock.git', :commit => '75a343f12c53e3fd60465ec36768f2a2b84b9131'
      pod 'SwiftyDropbox'
      pod 'SwiftNIO', '~> 2.18'
  end
end

