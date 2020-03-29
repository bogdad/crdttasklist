use_frameworks!
platform :ios, '12.0'

target 'crdttasklist' do
  pod 'IteratorTools', '~> 1.1.0'
  pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '0658371e574a0a66b1cd4bf5efe2665e00cf1ed8'
  pod 'SwiftyDropbox'

  target 'crdttasklistTests' do
      inherit! :search_paths
      pod 'IteratorTools', '~> 1.1.0'
  end

  target 'crdttasklistUITests' do
      use_frameworks!
      inherit! :search_paths
      pod 'IteratorTools', '~> 1.1.0'
      pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '0658371e574a0a66b1cd4bf5efe2665e00cf1ed8'
      pod 'SwiftyDropbox'
  end
end

