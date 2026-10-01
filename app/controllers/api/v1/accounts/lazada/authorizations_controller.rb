# frozen_string_literal: true

class Api::V1::Accounts::Lazada::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  before_action :ensure_lazada_enabled

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def create
    if params[:app_key].blank? || params[:app_secret].blank?
      render json: { error: 'app_key and app_secret are required' }, status: :unprocessable_entity
      return
    end

    state_token = SecureRandom.hex(24)
    state_payload = {
      account_id: Current.account.id,
      app_key: params[:app_key].to_s.strip,
      app_secret: params[:app_secret].to_s.strip,
      environment: params[:environment].presence || 'sandbox',
      inbox_name: params[:inbox_name].presence || 'Lazada Store',
      user_id: Current.user.id
    }

    ::Redis::Alfred.set("LAZADA_OAUTH:#{state_token}", state_payload.to_json, ex: 1800)

    callback_base = callback_base_url
    callback_url = "#{callback_base}/lazada/callback?state=#{state_token}"

    redirect_url = Lazada::Client.authorization_url(
      app_key: state_payload[:app_key],
      redirect_url: callback_url,
      environment: state_payload[:environment]
    )

    render json: { success: true, url: redirect_url }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  def ensure_lazada_enabled
    raise Pundit::NotAuthorizedError unless Current.account.feature_enabled?('channel_lazada')
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
