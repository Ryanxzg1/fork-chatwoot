# frozen_string_literal: true

require 'openssl'
require 'httparty'

class Lazada::Client
  include HTTParty
  default_timeout 10

  SANDBOX_BASE_URL = 'https://api.lazadaseller.com'
  PRODUCTION_BASE_URL = 'https://api.lazada.co.id'
  AUTH_SANDBOX_URL = 'https://auth.lazadaseller.com'
  AUTH_PRODUCTION_URL = 'https://auth.lazada.com'

  attr_reader :channel, :app_key, :app_secret, :environment, :seller_id, :access_token

  # rubocop:disable Metrics/ParameterLists
  def initialize(channel: nil, app_key: nil, app_secret: nil, environment: 'sandbox', seller_id: nil, access_token: nil)
    @channel = channel
    if channel
      @app_key = channel.app_key
      @app_secret = channel.app_secret
      @environment = channel.environment
      @seller_id = channel.seller_id
      @access_token = channel.access_token
    else
      @app_key = app_key
      @app_secret = app_secret
      @environment = environment || 'sandbox'
      @seller_id = seller_id
      @access_token = access_token
    end
  end
  # rubocop:enable Metrics/ParameterLists

  def self.authorization_url(app_key:, redirect_url:, environment: 'sandbox')
    auth_host = environment.to_s == 'production' ? 'https://auth.lazada.com' : 'https://auth.lazadaseller.com'
    "#{auth_host}/oauth/authorize?response_type=code&force_auth=true&redirect_uri=#{CGI.escape(redirect_url)}&client_id=#{app_key}"
  end

  def get_access_token(code:)
    params = build_signed_params({ code: code, grant_type: 'authorization_code' }, '/auth/token/create')
    response = HTTParty.get("#{auth_base_url}/auth/token/create", query: params, timeout: 10)
    body = JSON.parse(response.body)
    raise "Lazada token error: #{body['message']}" unless body['code'] == '0'

    extracted_seller_id = body['seller_id'] ||
                          body.dig('country_user_info', 0, 'seller_id') ||
                          body.dig('country_user_info', 0, 'user_id')

    {
      seller_id: extracted_seller_id,
      access_token: body['access_token'],
      refresh_token: body['refresh_token'],
      expires_at: Time.zone.at(body['expires_in'].to_i),
      refresh_token_expires_at: Time.zone.at(body['refresh_token_expires_in'].to_i)
    }
  end

  def refresh_access_token!
    params = build_signed_params({ refresh_token: channel.refresh_token, grant_type: 'refresh_token' }, '/auth/token/refresh')
    response = HTTParty.get("#{auth_base_url}/auth/token/refresh", query: params, timeout: 10)
    body = JSON.parse(response.body)
    raise "Lazada refresh error: #{body['message']}" unless body['code'] == '0'

    channel.update!(
      access_token: body['access_token'],
      refresh_token: body['refresh_token'] || channel.refresh_token,
      expires_at: Time.zone.at(body['expires_in'].to_i)
    )
  end

  def send_text_message(to_id:, text:)
    params = build_signed_params(
      { access_token: access_token, session_id: to_id, content: text, type: 'text' },
      '/im/message/send'
    )
    response = HTTParty.post("#{base_url}/im/message/send", query: params, timeout: 10)
    body = JSON.parse(response.body)
    raise "Lazada IM error: #{body['message']}" unless body['code'] == '0'

    body
  end

  private

  def base_url
    environment.to_s == 'production' ? PRODUCTION_BASE_URL : SANDBOX_BASE_URL
  end

  def auth_base_url
    environment.to_s == 'production' ? AUTH_PRODUCTION_URL : AUTH_SANDBOX_URL
  end

  # Lazada Open Platform uses lexicographic HMAC-SHA256 signature over all params
  def build_signed_params(extra_params, api_path)
    timestamp = (Time.current.to_f * 1000).to_i.to_s
    params = {
      app_key: app_key,
      timestamp: timestamp,
      sign_method: 'sha256'
    }.merge(extra_params.transform_keys(&:to_s))

    sorted = params.sort.to_h
    sign_str = api_path + sorted.map { |k, v| "#{k}#{v}" }.join
    params['sign'] = OpenSSL::HMAC.hexdigest('sha256', app_secret, sign_str).upcase
    params
  end
end
