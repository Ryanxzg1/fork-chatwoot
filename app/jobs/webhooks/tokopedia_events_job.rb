# frozen_string_literal: true

class Webhooks::TokopediaEventsJob < ApplicationJob
  queue_as :default

  KNOWN_TOKOPEDIA_TEST_SHOP_IDS = %w[0 sandbox test].freeze

  # rubocop:disable Metrics/CyclomaticComplexity
  def perform(params: {}, raw_post: '', signature: '')
    shop_id = params['shop_id'] || params['fs_id'] || params.dig('data', 'shop_id')
    return if shop_id.blank?

    channel = Channel::Tokopedia.find_by(shop_id: shop_id.to_s)
    channel ||= sandbox_fallback_channel(shop_id)

    unless channel&.inbox
      Rails.logger.warn "[Tokopedia Webhook] Channel or inbox not found for shop_id: #{shop_id}"
      return
    end

    unless valid_signature?(channel, raw_post, signature)
      Rails.logger.warn "[Tokopedia Webhook] Invalid or missing signature for shop_id: #{shop_id}"
      return
    end

    Tokopedia::IncomingMessageService.new(
      inbox: channel.inbox,
      params: params.with_indifferent_access
    ).perform
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def sandbox_fallback_channel(shop_id)
    return unless Rails.env.development? || Rails.env.test?
    return unless KNOWN_TOKOPEDIA_TEST_SHOP_IDS.include?(shop_id.to_s)

    Channel::Tokopedia.where(environment: 'sandbox').last
  end

  def valid_signature?(channel, raw_post, signature)
    if signature.blank?
      return false if Rails.env.production? || channel.environment == 'production'

      return true
    end

    expected_sign = OpenSSL::HMAC.hexdigest('sha256', channel.client_secret, raw_post)
    ActiveSupport::SecurityUtils.secure_compare(expected_sign, signature)
  end
end
