# frozen_string_literal: true

require 'openssl'
require 'httparty'

class Tokopedia::Client
  include HTTParty
  default_timeout 10

  SANDBOX_BASE_URL = 'https://fs.tokopedia.net'
  PRODUCTION_BASE_URL = 'https://fs.tokopedia.net'
  AUTH_BASE_URL = 'https://accounts.tokopedia.com'

  attr_reader :channel, :client_id, :client_secret, :environment, :shop_id, :access_token

  # rubocop:disable Metrics/ParameterLists
  def initialize(channel: nil, client_id: nil, client_secret: nil, environment: 'sandbox', shop_id: nil, access_token: nil)
    @channel = channel
    if channel
      @client_id = channel.client_id
      @client_secret = channel.client_secret
      @environment = channel.environment
      @shop_id = channel.shop_id
      @access_token = channel.access_token
    else
      @client_id = client_id
      @client_secret = client_secret
      @environment = environment || 'sandbox'
      @shop_id = shop_id
      @access_token = access_token
    end
  end
  # rubocop:enable Metrics/ParameterLists

  def self.authorization_url(client_id:, redirect_url:, **_opts)
    "#{AUTH_BASE_URL}/oauth/authorize?client_id=#{client_id}&redirect_uri=#{CGI.escape(redirect_url)}&response_type=code"
  end

  def get_access_token(code:)
    response = HTTParty.post(
      "#{AUTH_BASE_URL}/token",
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
      body: {
        grant_type: 'authorization_code',
        code: code,
        client_id: client_id,
        client_secret: client_secret
      },
      timeout: 10
    )

    body = JSON.parse(response.body)
    raise "Tokopedia token error: #{body['error_description'] || body['error']}" if response.code != 200

    {
      access_token: body['access_token'],
      refresh_token: body['refresh_token'],
      expires_at: Time.current + body['expires_in'].to_i.seconds,
      refresh_token_expires_at: 30.days.from_now
    }
  end

  def refresh_access_token!
    response = HTTParty.post(
      "#{AUTH_BASE_URL}/token",
      headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
      body: {
        grant_type: 'refresh_token',
        refresh_token: channel.refresh_token,
        client_id: client_id,
        client_secret: client_secret
      },
      timeout: 10
    )

    body = JSON.parse(response.body)
    raise "Tokopedia refresh error: #{body['error_description'] || body['error']}" if response.code != 200

    channel.update!(
      access_token: body['access_token'],
      refresh_token: body['refresh_token'] || channel.refresh_token,
      expires_at: Time.current + body['expires_in'].to_i.seconds
    )
  end

  def send_text_message(to_id:, text:)
    post_json('/v1/chat/send', { to_id: to_id, message: { type: 'text', text: text } })
  end

  private

  def base_url
    PRODUCTION_BASE_URL
  end

  def auth_headers
    {
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json'
    }
  end

  def post_json(path, body)
    response = HTTParty.post(
      "#{base_url}#{path}",
      headers: auth_headers,
      body: body.to_json,
      timeout: 10
    )
    raise "Tokopedia API error #{response.code}: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end
end
