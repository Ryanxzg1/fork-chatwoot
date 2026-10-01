# frozen_string_literal: true

class Lazada::CallbacksController < ApplicationController
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def show
    if params[:error].present?
      return redirect_to "/app/accounts/#{Current.account&.id || 1}/settings/inboxes/new?error=#{CGI.escape(params[:error].to_s)}"
    end

    state_token = params[:state]
    raw_state = ::Redis::Alfred.get("LAZADA_OAUTH:#{state_token}") if state_token.present?

    return redirect_to '/app/accounts/1/settings/inboxes/new?error=invalid_or_expired_state' if raw_state.blank?

    data = JSON.parse(raw_state)
    account = Account.find(data['account_id'])
    code = params[:code]
    seller_id = params[:seller_id] || params[:account_id]

    return redirect_to "/app/accounts/#{account.id}/settings/inboxes/new?error=missing_code" if code.blank?

    client = Lazada::Client.new(
      app_key: data['app_key'],
      app_secret: data['app_secret'],
      environment: data['environment']
    )

    token_data = client.get_access_token(code: code)

    # Prioritize seller_id from callback params or extracted token payload
    seller_id = params[:seller_id].presence || token_data[:seller_id].presence || data['app_key']

    channel = Channel::Lazada.find_or_initialize_by(
      account_id: account.id,
      seller_id: seller_id.to_s
    )

    channel.assign_attributes(
      app_key: data['app_key'],
      app_secret: data['app_secret'],
      access_token: token_data[:access_token],
      refresh_token: token_data[:refresh_token],
      expires_at: token_data[:expires_at],
      refresh_token_expires_at: token_data[:refresh_token_expires_at],
      environment: data['environment']
    )
    channel.save!

    inbox = channel.inbox || Inbox.create!(
      account: account,
      channel: channel,
      name: data['inbox_name'].presence || "Lazada - #{seller_id}"
    )

    ::Redis::Alfred.delete("LAZADA_OAUTH:#{state_token}")
    redirect_to "/app/accounts/#{account.id}/settings/inboxes/new/#{inbox.id}/agents"
  rescue StandardError => e
    Rails.logger.error "[Lazada::CallbacksController] Authorization error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to "/app/accounts/#{data&.dig('account_id') || 1}/settings/inboxes/new?error=#{CGI.escape(e.message)}"
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
