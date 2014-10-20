Gem::Specification.new do |s|

  s.name            = 'logstash-output-redis'
  s.version         = '0.1.0'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "This output will send events to a Redis queue using RPUSH"
  s.description     = "This output will send events to a Redis queue using RPUSH. Requires Redis Server 2.6.0+"
  s.authors         = ["Elasticsearch"]
  s.email           = 'richard.pijnenburg@elasticsearch.com'
  s.homepage        = "http://logstash.net/"
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)+::Dir.glob('vendor/*')

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency 'logstash', '>= 1.4.0', '< 2.0.0'

  s.add_runtime_dependency 'redis'
  s.add_runtime_dependency 'stud'

end

