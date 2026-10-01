# frozen_string_literal: true

class Tokopedia::CallbacksController < ApplicationController
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def show
    if params[:error].present?
      return redirect_to "/app/accounts/#{Current.account&.id || 1}/settings/inboxes/new?error=#{CGI.escape(params[:error].to_s)}"
    end

    state_token = params[:state]
    raw_state = ::Redis::Alfred.get("TOKOPEDIA_OAUTH:#{state_token}") if state_token.present?

    return redirect_to '/app/accounts/1/settings/inboxes/new?error=invalid_or_expired_state' if raw_state.blank?

    data = JSON.parse(raw_state)
    account = Account.find(data['account_id'])
    code = params[:code]
    shop_id = params[:shop_id] || params[:fs_id] || data['client_id']

    return redirect_to "/app/accounts/#{account.id}/settings/inboxes/new?error=missing_code" if code.blank?

    client = Tokopedia::Client.new(
      client_id: data['client_id'],
      client_secret: data['client_secret'],
      environment: data['environment']
    )

    token_data = client.get_access_token(code: code)

    channel = Channel::Tokopedia.find_or_initialize_by(
      account_id: account.id,
      shop_id: shop_id.to_s
    )

    channel.assign_attributes(
      client_id: data['client_id'],
      client_secret: data['client_secret'],
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
      name: data['inbox_name'].presence || "Tokopedia - #{shop_id}"
    )

    ::Redis::Alfred.delete("TOKOPEDIA_OAUTH:#{state_token}")
    redirect_to "/app/accounts/#{account.id}/settings/inboxes/new/#{inbox.id}/agents"
  rescue StandardError => e
    Rails.logger.error "[Tokopedia::CallbacksController] Authorization error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to "/app/accounts/#{data&.dig('account_id') || 1}/settings/inboxes/new?error=#{CGI.escape(e.message)}"
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
