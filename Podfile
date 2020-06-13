platform :ios, '12.0'

target 'crdttasklist' do
  use_modular_headers!
  pod 'IteratorTools', '~> 1.1.0'
  pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '0658371e574a0a66b1cd4bf5efe2665e00cf1ed8'
  pod 'SwiftyDropbox'
  pod 'SwiftNIO', '~> 2.18'
  inherit! :search_paths

  target 'crdttasklistTests' do
      inherit! :search_paths
      pod 'SwiftNIO', '~> 2.18'
      pod 'IteratorTools', '~> 1.1.0'
  end

  target 'crdttasklistUITests' do
      inherit! :search_paths
      pod 'IteratorTools', '~> 1.1.0'
      pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '0658371e574a0a66b1cd4bf5efe2665e00cf1ed8'
      pod 'SwiftyDropbox'
      pod 'SwiftNIO', '~> 2.18'
  end
end

