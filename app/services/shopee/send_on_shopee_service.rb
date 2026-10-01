# frozen_string_literal: true

class Shopee::SendOnShopeeService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Shopee
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def perform_reply
    buyer_id = contact_inbox.source_id.presence || contact.additional_attributes['shopee_user_id']
    raise 'Shopee buyer ID (source_id) is missing' if buyer_id.blank?

    response = if message.attachments.present?
                 send_attachment_message(buyer_id)
               else
                 send_text_message(buyer_id)
               end

    shopee_msg_id = response.is_a?(Hash) ? (response['message_id'] || response['msg_id']) : nil
    message.update!(source_id: shopee_msg_id) if shopee_msg_id.present?
    Messages::StatusUpdateService.new(message, 'delivered').perform
  rescue StandardError => e
    if sandbox_mock_eligible?(e)
      handle_sandbox_mock_delivery
      return
    end

    Rails.logger.error "[Shopee::SendOnShopeeService] Failed to send message #{message.id}: #{e.message}"
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
    raise e if Rails.env.test?
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def sandbox_mock_eligible?(error)
    return false unless channel.environment == 'sandbox'

    # Tolerate dummy buyer IDs in Sandbox so developers/testers can test CS replies smoothly
    error.message.include?('invalid_to_id') || error.message.include?('Invalid to_id')
  end

  def handle_sandbox_mock_delivery
    mock_id = "sandbox_msg_#{Time.current.to_i}_#{message.id}"
    message.update!(source_id: mock_id)
    Messages::StatusUpdateService.new(message, 'delivered').perform
    Rails.logger.info "[Shopee::SendOnShopeeService] Sandbox mock delivery handled for message #{message.id} (simulated buyer)"
  end

  def send_text_message(buyer_id)
    text = message.outgoing_content.presence || message.content
    channel.client.send_text_message(to_id: buyer_id, text: text)
  end

  def send_attachment_message(buyer_id)
    attachment = message.attachments.first
    if attachment.image?
      image_url = channel.client.upload_image(attachment.file.blob)
      channel.client.send_image_message(to_id: buyer_id, image_url: image_url)
    else
      # If not an image, send file link / fallback text
      fallback_text = "#{message.content}\n#{attachment.file_url}"
      channel.client.send_text_message(to_id: buyer_id, text: fallback_text)
    end
  end

  def channel
    @channel ||= inbox.channel
  end
end
