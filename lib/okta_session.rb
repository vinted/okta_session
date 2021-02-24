# frozen_string_literal: true

require 'httparty'
require 'io/console'
require 'nokogiri'
require 'json'

class OktaSession
  attr_reader :session, :service_host, :service_url, :app_id

  OKTA_URL = 'https://vinted.okta-emea.com'
  SESSION_CACHE = File.join(File.expand_path('~'), 'okta_session_cache')

  FACTOR_METHOD = ENV['OKTA_FACTOR'] || 'push'

  def initialize(service_host:, app_id:)
    @service_host = service_host
    @service_url = "https://#{service_host}"
    @app_id = app_id

    @session =
      if File.exist?(SESSION_CACHE)
        JSON.parse(File.read(SESSION_CACHE))
      else
        {}
      end
  end

  def get(path, opts = {})
    session_request(:get, File.join(service_url, path), opts)
  end

  def post(path, opts = {})
    session_request(:post, File.join(service_url, path), opts)
  end

  def put(path, opts = {})
    session_request(:put, File.join(service_url, path), opts)
  end

  private

  def establish_session
    saml_url = get('auth/saml', follow_redirects: false).headers['location']

    post(
      'auth/saml/callback',
      headers: { referer: saml_url },
      body: { SAMLResponse: saml(saml_url), RelayState: '' }
    )
  end

  def saml(saml_url, try = 0)
    response = session_request(:get, saml_url, follow_redirects: false)

    if response.code == 200
      Nokogiri::HTML
        .parse(response)
        .xpath("//html//form/input[@name='SAMLResponse']/@value").to_s
    elsif try < 1
      authenticate
      saml(saml_url, try + 1)
    else
      raise 'Failed authenticating to OKTA!'
    end
  end

  def authenticate
    print 'Your OKTA email: '
    email = $stdin.gets.chomp
    password = IO.console.getpass('Your OKTA password: ')

    response = session_request(
      :post,
      "#{OKTA_URL}/api/v1/authn",
      headers: { 'Content-Type' => 'application/json' },
      body: { 'username' => email, 'password' => password }.to_json,
      follow_redirects: false
    )

    case response['status']
    when 'MFA_ENROLL'
      raise 'OKTA is not set up for your account! Please contact IT (#it slack channel)'
    when 'MFA_REQUIRED'
      handle_mfa(session_token(response['stateToken'], factor_id(response)))
    when 'SUCCESS'
      handle_mfa(response['sessionToken'])
    else
      raise <<~MSG
        Unrecognized OKTA authn response status: `#{response['status']}`
        Full OKTA response:
        #{response}
      MSG
    end
  end

  def factor_id(response)
    response['_embedded']['factors'].find { |factor| factor['factorType'] == FACTOR_METHOD }['id']
  rescue StandardError => e
    puts e
    puts response
    raise
  end

  def handle_mfa(session_token)
    session_request(
      :get,
      "#{OKTA_URL}/login/sessionCookieRedirect?" + URI.encode_www_form(
        'checkAccountSetupComplete' => true,
        'token' => session_token,
        'redirectUrl' => File.join(OKTA_URL, app_id)
      ),
      follow_redirects: false
    )
  end

  def push_factor(state_token, factor_id, try = 0)
    response = factor_request(state_token, factor_id)

    if response['status'] == 'SUCCESS'
      response['sessionToken']
    elsif try < 10
      sleep 4
      puts 'polling for verification...'
      push_factor(state_token, factor_id, try + 1)
    else
      raise 'Failed authenticating to OKTA!'
    end
  end

  def sms_factor(state_token, factor_id)
    unless factor_request(state_token, factor_id)['status'] == 'MFA_CHALLENGE'
      raise 'Failed sending verification SMS, please try again'
    end

    puts 'SMS verification code sent!'
    print 'Enter code: '
    code = $stdin.gets.chomp

    response = factor_request(state_token, factor_id, { 'passCode' => code })
    if response['status'] == 'SUCCESS'
      response['sessionToken']
    else
      raise 'Failed verifying OKTA SMS code!'
    end
  end

  def factor_request(state_token, factor_id, extra = {})
    session_request(
      :post,
      "#{OKTA_URL}/api/v1/authn/factors/#{factor_id}/verify",
      headers: { 'Content-Type' => 'application/json' },
      body: { 'stateToken' => state_token }.merge(extra).to_json
    )
  end

  def session_token(state_token, factor_id)
    case FACTOR_METHOD
    when 'push'
      puts('Sending push notification...')
      push_factor(state_token, factor_id)
    when 'sms'
      sms_factor(state_token, factor_id)
    else
      raise "OKTA login via #{FACTOR_METHOD} is unsupported!"
    end
  end

  def parsed_cookies(set_cookies)
    set_cookies.map { |set_cookie| set_cookie.split(';').first.strip.split('=') }.to_h
  end

  def session_request(method, url, opts = {})
    host = URI.parse(url).host
    response = HTTParty.public_send(
      method,
      url,
      opts.merge(
        cookies: session_of(host),
        timeout: 3600 # for downloading huge files
      )
    )

    if response.body.include?('Vinted - Sign In')
      establish_session
      session_request(method, url, opts)
    else
      update_session!(host, response)
      response
    end
  end

  def update_session!(host, response)
    @session[host] = session_of(host).merge(
      parsed_cookies(response.get_fields('Set-Cookie') || [])
    )

    File.open(SESSION_CACHE, 'w') do |f|
      f.chmod(0o600)
      f.write(session.to_json)
    end
  end

  def session_of(host)
    session[host] || {}
  end
end
