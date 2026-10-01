# frozen_string_literal: true

class Api::V1::Accounts::Shopee::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  before_action :ensure_shopee_enabled

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def create
    if params[:partner_id].blank? || params[:partner_key].blank?
      render json: { error: 'partner_id and partner_key are required' }, status: :unprocessable_entity
      return
    end

    state_token = SecureRandom.hex(24)
    state_payload = {
      account_id: Current.account.id,
      partner_id: params[:partner_id].to_s.strip,
      partner_key: params[:partner_key].to_s.strip,
      environment: params[:environment].presence || 'sandbox',
      inbox_name: params[:inbox_name].presence || 'Shopee Store',
      user_id: Current.user.id
    }

    ::Redis::Alfred.set("SHOPEE_OAUTH:#{state_token}", state_payload.to_json, ex: 1800)

    callback_base = callback_base_url
    callback_url = "#{callback_base}/shopee/callback?state=#{state_token}"

    redirect_url = Shopee::Client.authorization_url(
      partner_id: state_payload[:partner_id],
      partner_key: state_payload[:partner_key],
      redirect_url: callback_url,
      environment: state_payload[:environment]
    )

    render json: { success: true, url: redirect_url }
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  private

  def ensure_shopee_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('channel_shopee')
  end

  def callback_base_url
    url = params[:redirect_url].presence
    return request.base_url if url.blank?

    uri = URI.parse(url)
    return url.chomp('/') if valid_redirect_uri?(uri)

    request.base_url
  rescue URI::InvalidURIError
    request.base_url
  end

  def valid_redirect_uri?(uri)
    return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    return true if allowed_development_host?(uri.host)

    allowed_hosts = [request.host, configured_frontend_host].compact
    allowed_hosts.include?(uri.host)
  end

  def allowed_development_host?(host)
    return false unless Rails.env.development? || Rails.env.test?

    host.to_s.end_with?('.trycloudflare.com') || %w[localhost 127.0.0.1].include?(host)
  end

  def configured_frontend_host
    URI.parse(ENV.fetch('FRONTEND_URL', '')).host
  rescue URI::InvalidURIError
    nil
  end
end
