# frozen_string_literal: true

class Tokopedia::SendOnTokopediaService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Tokopedia
  end

  # rubocop:disable Metrics/AbcSize
  def perform_reply
    buyer_id = contact_inbox.source_id.presence || contact.additional_attributes['tokopedia_user_id']
    raise 'Tokopedia buyer ID (source_id) is missing' if buyer_id.blank?

    response = channel.client.send_text_message(to_id: buyer_id, text: message.content)
    msg_id = response.is_a?(Hash) ? response['message_id'] : nil
    message.update!(source_id: msg_id) if msg_id.present?
    Messages::StatusUpdateService.new(message, 'delivered').perform
  rescue StandardError => e
    Rails.logger.error "[Tokopedia::SendOnTokopediaService] Failed to send message #{message.id}: #{e.message}"
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
    raise e if Rails.env.test?
  end
  # rubocop:enable Metrics/AbcSize
end
