use_frameworks!
platform :ios, '12.0'

target 'crdttasklist' do
  pod 'IteratorTools', '~> 1.1.0'
  pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '66c22d815ad192af2ccff1d8389c2dfcabe023de'
  pod 'SwiftyDropbox'

  target 'crdttasklistTests' do
      inherit! :search_paths
      pod 'IteratorTools', '~> 1.1.0'
  end

  target 'crdttasklistUITests' do
      use_frameworks!
      inherit! :search_paths
      pod 'IteratorTools', '~> 1.1.0'
      pod 'BTree', :git => 'https://github.com/bogdad/BTree.git', :commit => '66c22d815ad192af2ccff1d8389c2dfcabe023de'
      pod 'SwiftyDropbox'
  end
end

