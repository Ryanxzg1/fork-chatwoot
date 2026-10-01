# frozen_string_literal: true

require 'openssl'
require 'httparty'

# rubocop:disable Metrics/ClassLength
class Shopee::Client
  SANDBOX_BASE_URL = 'https://openplatform.sandbox.test-stable.shopee.sg'
  PRODUCTION_BASE_URL = 'https://partner.shopeemobile.com'

  attr_reader :channel, :partner_id, :partner_key, :environment, :shop_id, :access_token

  # rubocop:disable Metrics/ParameterLists
  def initialize(channel: nil, partner_id: nil, partner_key: nil, environment: 'sandbox', shop_id: nil, access_token: nil)
    @channel = channel
    if channel
      @partner_id = channel.partner_id
      @partner_key = channel.partner_key
      @environment = channel.environment
      @shop_id = channel.shop_id
      @access_token = channel.access_token
    else
      @partner_id = partner_id
      @partner_key = partner_key
      @environment = environment || 'sandbox'
      @shop_id = shop_id
      @access_token = access_token
    end
  end
  # rubocop:enable Metrics/ParameterLists

  def base_url
    environment.to_s == 'production' ? PRODUCTION_BASE_URL : SANDBOX_BASE_URL
  end

  def self.authorization_url(partner_id:, partner_key:, redirect_url:, environment: 'sandbox')
    path = '/api/v2/shop/auth_partner'
    timestamp = Time.current.to_i
    base_string = "#{partner_id}#{path}#{timestamp}"
    sign = OpenSSL::HMAC.hexdigest('sha256', partner_key, base_string)

    host = environment.to_s == 'production' ? PRODUCTION_BASE_URL : SANDBOX_BASE_URL
    query = URI.encode_www_form(
      partner_id: partner_id,
      timestamp: timestamp,
      sign: sign,
      redirect: redirect_url
    )

    "#{host}#{path}?#{query}"
  end

  def get_access_token(code:, shop_id:)
    path = '/api/v2/auth/token/get'
    timestamp = Time.current.to_i
    sign = generate_signature(path: path, timestamp: timestamp)

    endpoint = "#{base_url}#{path}"
    query = { partner_id: partner_id.to_i, timestamp: timestamp, sign: sign }
    body = { code: code, shop_id: shop_id.to_i, partner_id: partner_id.to_i }

    response = post_request(endpoint, query: query, body: body)
    handle_token_response(response)
  end

  def refresh_access_token!
    raise 'Channel required for refreshing access token' unless channel

    path = '/api/v2/auth/access_token/get'
    timestamp = Time.current.to_i
    sign = generate_signature(path: path, timestamp: timestamp)

    endpoint = "#{base_url}#{path}"
    query = { partner_id: partner_id.to_i, timestamp: timestamp, sign: sign }
    body = { refresh_token: channel.refresh_token, shop_id: channel.shop_id.to_i, partner_id: partner_id.to_i }

    response = post_request(endpoint, query: query, body: body)
    data = handle_token_response(response)

    channel.update!(
      access_token: data[:access_token],
      refresh_token: data[:refresh_token],
      expires_at: data[:expires_at],
      refresh_token_expires_at: data[:refresh_token_expires_at]
    )

    @access_token = data[:access_token]
    data
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def send_text_message(to_id:, text:, retry_count: 0)
    ensure_valid_token!

    path = '/api/v2/sellerchat/send_message'
    timestamp = Time.current.to_i
    sign = generate_signature(path: path, timestamp: timestamp, access_token: access_token, shop_id: shop_id)

    endpoint = "#{base_url}#{path}"
    query = {
      partner_id: partner_id.to_i,
      timestamp: timestamp,
      access_token: access_token,
      shop_id: shop_id.to_i,
      sign: sign
    }
    body = {
      to_id: to_id.to_i,
      message_type: 'text',
      content: { text: text }
    }

    response = post_request(endpoint, query: query, body: body)
    parsed = parse_response(response)

    if parsed['error'].present? && parsed['error'] != ''
      if auth_error?(parsed['error']) && retry_count < 1
        refresh_access_token!
        return send_text_message(to_id: to_id, text: text, retry_count: retry_count + 1)
      end
      raise "Shopee API error: #{parsed['error']} - #{parsed['message']}"
    end

    parsed['response'] || parsed
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  def upload_image(file_or_blob)
    ensure_valid_token!

    path = '/api/v2/sellerchat/upload_image'
    timestamp = Time.current.to_i
    sign = generate_signature(path: path, timestamp: timestamp, access_token: access_token, shop_id: shop_id)

    endpoint = "#{base_url}#{path}?partner_id=#{partner_id}&timestamp=#{timestamp}&access_token=#{access_token}&shop_id=#{shop_id}&sign=#{sign}"

    file_io = file_or_blob.respond_to?(:download) ? StringIO.new(file_or_blob.download) : File.open(file_or_blob)
    file_or_blob.respond_to?(:filename) ? file_or_blob.filename.to_s : File.basename(file_or_blob)

    response = HTTParty.post(
      endpoint,
      multipart: true,
      body: { file: file_io },
      headers: { 'Content-Type' => 'multipart/form-data' },
      timeout: 30
    )

    parsed = parse_response(response)
    raise "Shopee Image Upload failed: #{parsed['error']} - #{parsed['message']}" if parsed['error'].present? && parsed['error'] != ''

    parsed.dig('response', 'url') || parsed.dig('response', 'thumb_url')
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def send_image_message(to_id:, image_url:, retry_count: 0)
    ensure_valid_token!

    path = '/api/v2/sellerchat/send_message'
    timestamp = Time.current.to_i
    sign = generate_signature(path: path, timestamp: timestamp, access_token: access_token, shop_id: shop_id)

    endpoint = "#{base_url}#{path}"
    query = {
      partner_id: partner_id.to_i,
      timestamp: timestamp,
      access_token: access_token,
      shop_id: shop_id.to_i,
      sign: sign
    }
    body = {
      to_id: to_id.to_i,
      message_type: 'image',
      content: { image_url: image_url }
    }

    response = post_request(endpoint, query: query, body: body)
    parsed = parse_response(response)

    if parsed['error'].present? && parsed['error'] != ''
      if auth_error?(parsed['error']) && retry_count < 1
        refresh_access_token!
        return send_image_message(to_id: to_id, image_url: image_url, retry_count: retry_count + 1)
      end
      raise "Shopee API error: #{parsed['error']} - #{parsed['message']}"
    end

    parsed['response'] || parsed
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  private

  def ensure_valid_token!
    return unless channel&.token_expired?

    refresh_access_token!
  end

  def generate_signature(path:, timestamp:, access_token: nil, shop_id: nil)
    base_string = if access_token && shop_id
                    "#{partner_id}#{path}#{timestamp}#{access_token}#{shop_id}"
                  else
                    "#{partner_id}#{path}#{timestamp}"
                  end
    OpenSSL::HMAC.hexdigest('sha256', partner_key, base_string)
  end

  def post_request(endpoint, query:, body:)
    HTTParty.post(
      endpoint,
      query: query,
      body: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      timeout: 20
    )
  end

  def parse_response(response)
    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "[Shopee::Client] JSON Parse error: #{e.message} for body: #{response.body}"
    { 'error' => 'json_parse_error', 'message' => e.message }
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def handle_token_response(response)
    parsed = parse_response(response)
    raise "Shopee Auth Error: #{parsed['error']} - #{parsed['message']}" if parsed['error'].present? && parsed['error'] != ''

    data = parsed['response'].is_a?(Hash) ? parsed['response'] : parsed
    expire_in = (data['expire_in'] || data['expires_in'] || parsed['expire_in'] || 14_400).to_i
    refresh_expire_in = (data['refresh_token_expire_in'] || parsed['refresh_token_expire_in'] || 30.days.to_i).to_i

    {
      access_token: data['access_token'] || parsed['access_token'],
      refresh_token: data['refresh_token'] || parsed['refresh_token'],
      shop_id: data['shop_id'] || parsed['shop_id'] || shop_id,
      expires_at: Time.current + expire_in.seconds,
      refresh_token_expires_at: Time.current + refresh_expire_in.seconds
    }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def auth_error?(error_code)
    %w[error_auth error_access_token error_token_expired invalid_token].include?(error_code.to_s.downcase)
  end
end
# rubocop:enable Metrics/ClassLength
