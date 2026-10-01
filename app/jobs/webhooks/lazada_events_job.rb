# frozen_string_literal: true

class Webhooks::LazadaEventsJob < ApplicationJob
  queue_as :default

  def perform(params: {}, raw_post: '', signature: '')
    seller_id = params['seller_id'] || params.dig('data', 'seller_id')
    return if seller_id.blank?

    channel = Channel::Lazada.find_by(seller_id: seller_id.to_s)
    unless channel&.inbox
      Rails.logger.warn "[Lazada Webhook] Channel or inbox not found for seller_id: #{seller_id}"
      return
    end

    if signature.present? && !valid_signature?(channel, raw_post, signature)
      Rails.logger.warn "[Lazada Webhook] Invalid signature for seller_id: #{seller_id}"
      return
    end

    Rails.logger.info "[Lazada Webhook] Successfully received event for seller_id #{seller_id}: #{params.inspect}"
  end

  private

  def valid_signature?(channel, raw_post, signature)
    expected_sign = OpenSSL::HMAC.hexdigest('sha256', channel.app_secret, raw_post)
    ActiveSupport::SecurityUtils.secure_compare(expected_sign.upcase, signature.upcase)
  end
end
