Gem::Specification.new do |s|
  s.name	      = 'hive-runner-ios'
  s.version	    = '0.0.1'
  s.date 	      = '2015-02-26'
  s.summary	    = 'Hive Runner iOS'
  s.description	= 'The iOS controller module for Hive Runner'
  s.authors	    = ['Jon Wilson']
  s.email	      = 'jon.wilson01@bbc.co.uk'
  s.files 	    = Dir['README.md', 'lib/**/*.rb']
  s.homepage  	= 'https://github.com/bbc/hive-runner-ios'
  s.license	    = 'MIT'
  s.add_runtime_dependency 'device_api-ios'
end
