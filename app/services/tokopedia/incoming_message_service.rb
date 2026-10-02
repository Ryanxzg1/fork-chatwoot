# frozen_string_literal: true

class Tokopedia::IncomingMessageService
  pattr_initialize [:inbox!, :params!]

  # rubocop:disable Metrics/CyclomaticComplexity
  def perform
    return if params.blank?

    data = params.key?('data') ? params['data'] : params
    return unless data.is_a?(Hash)

    sender_id = resolve_sender_id(data)
    return if sender_id.blank?

    # Ignore messages sent by the shop itself (echoes)
    return if sender_id.to_s == inbox.channel.shop_id.to_s

    message_id = resolve_message_id(data, sender_id)
    text_content = extract_text_content(data)

    return if text_content.blank?

    set_contact(sender_id, data)
    set_conversation

    return if message_already_exists?(message_id)

    create_message(message_id, text_content)
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  private

  def resolve_sender_id(data)
    candidate_keys = %w[sender_id from_id buyer_id user_id]
    sender = candidate_keys.filter_map { |k| data[k] }.first || data.dig('content', 'user_id')
    return sender.to_s if sender.present? && sender.to_s != '0'

    # Fallback for Tokopedia sandbox testing
    'tokopedia_tester' if inbox.channel.environment == 'sandbox'
  end

  def resolve_message_id(data, sender_id)
    candidate_id_keys = %w[msg_id message_id id]
    msg_id = candidate_id_keys.filter_map { |k| params[k] || data[k] }.first
    return msg_id.to_s if msg_id.present?

    "#{sender_id}_#{Time.current.to_f}"
  end

  def extract_text_content(data)
    extracted = raw_message_text(data)
    return extracted if extracted.present?
    return unless inbox.channel.environment == 'sandbox'

    event_type = data['type'] || data['event'] || data.dig('content', 'type') || 'Tokopedia Chat'
    "🔔 [Tokopedia Chat Push] Pesan uji coba diterima dari Tokopedia Console (#{event_type})"
  end

  def raw_message_text(data)
    if data['content'].is_a?(Hash)
      data.dig('content', 'text').presence || data.dig('content', 'message').presence
    else
      data['message'] || data['text'] || data['content']
    end
  end

  def resolve_contact_name(sender_id, data)
    data['sender_name'].presence || data['from_name'].presence || data['buyer_name'].presence || default_contact_name(sender_id, data)
  end

  def default_contact_name(sender_id, data)
    return 'Tokopedia Tester' if sender_id.to_s.include?('tokopedia') || data['type'] == 'notification'

    "Tokopedia Buyer #{sender_id}"
  end

  def set_contact(sender_id, data)
    contact_attributes = {
      name: resolve_contact_name(sender_id, data),
      additional_attributes: {
        tokopedia_user_id: sender_id,
        shop_id: inbox.channel.shop_id
      }
    }

    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: sender_id,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform
    @contact = @contact_inbox.contact
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end

    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        type: 'tokopedia_chat',
        shop_id: inbox.channel.shop_id
      }
    )
  end

  def message_already_exists?(message_id)
    @conversation.messages.exists?(source_id: message_id)
  end

  def create_message(message_id, content)
    @conversation.messages.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      content: content,
      source_id: message_id,
      sender: @contact
    )
  end
end
