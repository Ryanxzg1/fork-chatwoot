# frozen_string_literal: true

class Shopee::CallbacksController < ApplicationController
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def show
    if params[:error].present?
      return redirect_to "/app/accounts/#{Current.account&.id || 1}/settings/inboxes/new?error=#{CGI.escape(params[:error].to_s)}"
    end

    state_token = params[:state]
    raw_state = ::Redis::Alfred.get("SHOPEE_OAUTH:#{state_token}") if state_token.present?

    return redirect_to '/app/accounts/1/settings/inboxes/new?error=invalid_or_expired_state' if raw_state.blank?

    data = JSON.parse(raw_state)
    account = Account.find(data['account_id'])

    code = params[:code]
    shop_id = params[:shop_id]

    return redirect_to "/app/accounts/#{account.id}/settings/inboxes/new?error=missing_code_or_shop_id" if code.blank? || shop_id.blank?

    client = Shopee::Client.new(
      partner_id: data['partner_id'],
      partner_key: data['partner_key'],
      environment: data['environment'],
      shop_id: shop_id
    )

    token_data = client.get_access_token(code: code, shop_id: shop_id)

    channel = Channel::Shopee.find_or_initialize_by(
      account_id: account.id,
      shop_id: shop_id.to_s
    )

    channel.assign_attributes(
      partner_id: data['partner_id'],
      partner_key: data['partner_key'],
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
      name: data['inbox_name'].presence || "Shopee - #{shop_id}"
    )

    ::Redis::Alfred.delete("SHOPEE_OAUTH:#{state_token}")

    redirect_to "/app/accounts/#{account.id}/settings/inboxes/new/#{inbox.id}/agents"
  rescue StandardError => e
    Rails.logger.error "[Shopee::CallbacksController] Authorization error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to "/app/accounts/#{data&.dig('account_id') || 1}/settings/inboxes/new?error=#{CGI.escape(e.message)}"
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
