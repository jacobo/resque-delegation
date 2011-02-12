require 'lib/resque/plugins/delegation/version'

Gem::Specification.new do |s|
  s.name              = 'resque-delgation'
  s.version           = Resque::Plugins::Delegation::Version
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = 'A Resque plugin for stuff'
  s.homepage          = 'http://github.com/jacobo/resque-delegation'
  s.email             = 'jburkhart@engineyard.com'
  s.authors           = [ 'Jacob Burkhart' ]
  s.has_rdoc          = false

  s.files             = %w( README.markdown Rakefile LICENSE )
  s.files            += Dir.glob('lib/**/*')
  s.files            += Dir.glob('spec/**/*')

  s.add_dependency 'resque', '>= 1.8.0'
  s.add_dependency 'resque-meta', '>= 1.0.0'

  s.add_development_dependency 'rspec'

  s.description       = "A Resque plugin that does stuff"

end