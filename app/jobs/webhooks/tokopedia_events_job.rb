# frozen_string_literal: true

class Webhooks::TokopediaEventsJob < ApplicationJob
  queue_as :default

  # rubocop:disable Metrics/CyclomaticComplexity
  def perform(params: {}, raw_post: '', signature: '')
    shop_id = params['shop_id'] || params['fs_id'] || params.dig('data', 'shop_id')
    return if shop_id.blank?

    channel = Channel::Tokopedia.find_by(shop_id: shop_id.to_s)
    unless channel&.inbox
      Rails.logger.warn "[Tokopedia Webhook] Channel or inbox not found for shop_id: #{shop_id}"
      return
    end

    if signature.present? && !valid_signature?(channel, raw_post, signature)
      Rails.logger.warn "[Tokopedia Webhook] Invalid signature for shop_id: #{shop_id}"
      return
    end

    Rails.logger.info "[Tokopedia Webhook] Successfully received event for shop_id #{shop_id}: #{params.inspect}"
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def valid_signature?(channel, raw_post, signature)
    expected_sign = OpenSSL::HMAC.hexdigest('sha256', channel.client_secret, raw_post)
    ActiveSupport::SecurityUtils.secure_compare(expected_sign, signature)
  end
end
