# frozen_string_literal: true

class Webhooks::LazadaEventsJob < ApplicationJob
  queue_as :default

  KNOWN_LAZADA_TEST_SELLER_IDS = %w[0 sandbox test].freeze

  def perform(params: {}, raw_post: '', signature: '')
    seller_id = params['seller_id'] || params.dig('data', 'seller_id')
    return if seller_id.blank?

    channel = Channel::Lazada.find_by(seller_id: seller_id.to_s)
    channel ||= sandbox_fallback_channel(seller_id)

    unless channel&.inbox
      Rails.logger.warn "[Lazada Webhook] Channel or inbox not found for seller_id: #{seller_id}"
      return
    end

    unless valid_signature?(channel, raw_post, signature)
      Rails.logger.warn "[Lazada Webhook] Invalid or missing signature for seller_id: #{seller_id}"
      return
    end

    Lazada::IncomingMessageService.new(
      inbox: channel.inbox,
      params: params.with_indifferent_access
    ).perform
  end

  private

  def sandbox_fallback_channel(seller_id)
    return unless Rails.env.development? || Rails.env.test?
    return unless KNOWN_LAZADA_TEST_SELLER_IDS.include?(seller_id.to_s)

    Channel::Lazada.where(environment: 'sandbox').last
  end

  def valid_signature?(channel, raw_post, signature)
    if signature.blank?
      return false if Rails.env.production? || channel.environment == 'production'

      return true
    end

    expected_sign = OpenSSL::HMAC.hexdigest('sha256', channel.app_secret, raw_post)
    ActiveSupport::SecurityUtils.secure_compare(expected_sign.upcase, signature.upcase)
  end
end
