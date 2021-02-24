Gem::Specification.new do |s|
  s.name        = 'okta_session'
  s.version     = '0.3.4'
  s.date        = '2020-06-12'
  s.summary     = 'A ruby library for Interacting with OKTA secured services via the command line'
  s.description = 'A ruby library for Interacting with OKTA secured services via the command line'
  s.authors     = ["vLukas-dev"]
  s.files       = ['lib/okta_session.rb']
  s.homepage    =  'http://github.com/vinted/okta_session'
  s.add_dependency 'httparty'
  s.add_dependency 'nokogiri'
  s.add_dependency 'json'
end
