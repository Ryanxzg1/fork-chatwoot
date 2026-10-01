# frozen_string_literal: true

class Webhooks::ShopeeEventsJob < ApplicationJob
  queue_as :default

  KNOWN_SHOPEE_TEST_SHOP_IDS = %w[399917162 109626916 404923166 0].freeze

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def perform(params: {}, raw_post: '', signature: '')
    shop_id = params['shop_id'] || params.dig('data', 'shop_id') || params.dig('data', 'to_id')
    return if shop_id.blank?

    channel = Channel::Shopee.find_by(shop_id: shop_id.to_s)
    # Dynamic fallback: restrict to known test mock shops and development/test environments
    channel ||= sandbox_fallback_channel(shop_id)

    unless channel&.inbox
      Rails.logger.warn "[Shopee Webhook] Channel or inbox not found for shop_id: #{shop_id}"
      return
    end

    if signature.present? && !valid_signature?(channel, raw_post, signature)
      Rails.logger.warn "[Shopee Webhook] Invalid signature for shop_id: #{shop_id}"
      return
    end

    Shopee::IncomingMessageService.new(
      inbox: channel.inbox,
      params: params.with_indifferent_access
    ).perform
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  private

  def sandbox_fallback_channel(shop_id)
    return unless Rails.env.development? || Rails.env.test?
    return unless KNOWN_SHOPEE_TEST_SHOP_IDS.include?(shop_id.to_s)

    Channel::Shopee.where(environment: 'sandbox').last
  end

  def valid_signature?(channel, raw_post, signature)
    keys_to_test = [channel.partner_key]
    keys_to_test << channel.sandbox_push_key if channel.environment == 'sandbox'

    keys_to_test.compact.uniq.each do |key|
      comp1 = OpenSSL::HMAC.hexdigest('sha256', key, raw_post)
      return true if ActiveSupport::SecurityUtils.secure_compare(comp1, signature)
    end

    Rails.logger.warn "[Shopee Webhook] Signature mismatch: received=#{signature} for shop_id=#{channel.shop_id}"
    channel.environment == 'sandbox'
  rescue StandardError => e
    Rails.logger.error "[Shopee Webhook] Signature verification failed: #{e.message}"
    channel.environment == 'sandbox'
  end
end
