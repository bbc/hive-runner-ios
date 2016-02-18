Gem::Specification.new do |s|
  s.name          = 'hive-runner-ios'
  s.version       = '1.0.5'
  s.date          = Time.now.strftime("%Y-%m-%d")
  s.summary       = 'Hive Runner iOS'
  s.description   = 'The iOS controller module for Hive Runner'
  s.authors       = ['Jon Wilson']
  s.email         = 'jon.wilson01@bbc.co.uk'
  s.files         = Dir['README.md', 'lib/**/*.rb']
  s.homepage      = 'https://github.com/bbc/hive-runner-ios'
  s.license       = 'MIT'
  s.add_runtime_dependency 'device_api-ios', '~> 1.0'
  s.add_runtime_dependency 'fruity_builder', '>= 0'
end
