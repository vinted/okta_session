okta_session
========
A ruby library for Interacting with OKTA secured services via the command line.

Example
=======

```ruby
session = OktaSession.new(service_host: 'analytics.vinted.net', app_id: 'vinted_analyticssaml_2')
session.get('https://analytics.vinted.net/status')
```
