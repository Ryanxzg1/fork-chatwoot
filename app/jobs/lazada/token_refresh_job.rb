# frozen_string_literal: true

class Lazada::TokenRefreshJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::Lazada.where('expires_at <= ? AND refresh_token_expires_at > ?', 1.hour.from_now, Time.current).find_each do |channel|
      channel.refresh_access_token!
    rescue StandardError => e
      Rails.logger.error "[Lazada::TokenRefreshJob] Failed to refresh token for channel #{channel.id} (seller_id: #{channel.seller_id}): #{e.message}"
      channel.authorization_error! if channel.respond_to?(:authorization_error!)
    end
  end
end
