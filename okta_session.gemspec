$:.push File.expand_path("../lib", __FILE__)

require 'okta_session/version'

Gem::Specification.new do |s|
  s.name        = 'okta_session'
  s.version     = OktaSession::VERSION
  s.summary     = 'A ruby library for Interacting with OKTA secured services via the command line'
  s.description = 'A ruby library for Interacting with OKTA secured services via the command line'
  s.authors     = ["vinted"]
  s.files       = ['lib/okta_session.rb']
  s.homepage    =  'https://github.com/vinted/okta_session'
  s.metadata['allowed_push_host'] = 'https://nexus.vinted.net'
  s.add_dependency 'httparty'
  s.add_dependency 'nokogiri'
  s.add_dependency 'json'
  s.add_development_dependency "rake", "~> 10.0"
end
