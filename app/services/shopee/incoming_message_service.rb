# frozen_string_literal: true

class Shopee::IncomingMessageService
  pattr_initialize [:inbox!, :params!]

  # rubocop:disable Metrics/CyclomaticComplexity
  def perform
    return if params.blank?

    data = params['data'] || params
    return if data.blank?

    sender_id = resolve_sender_id(data)
    return if sender_id.blank?

    # Ignore messages sent by the shop itself (echoes)
    return if sender_id == inbox.channel.shop_id.to_s

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
    sender = (data['from_id'] || data['sender_id'] || data['buyer_user_id'] || data.dig('content', 'user_id')).to_s
    return sender if sender.present? && sender != '0'

    # Fallback for Shopee Console test pushes in sandbox
    'shopee_console_tester' if inbox.channel.environment == 'sandbox'
  end

  def resolve_message_id(data, sender_id)
    msg_id = (params['msg_id'] || data['message_id']).presence
    if msg_id.present?
      # Shopee Console repeats static sample msg_id, append timestamp in sandbox
      return "#{msg_id}_#{Time.current.to_i}" if inbox.channel.environment == 'sandbox'

      return msg_id.to_s
    end

    "#{sender_id}_#{Time.current.to_f}"
  end

  def extract_text_content(data)
    extracted = raw_message_text(data)
    return extracted if extracted.present?
    return unless inbox.channel.environment == 'sandbox'

    event_type = data['type'] || data.dig('content', 'type') || 'Webchat Push'
    "🔔 [Shopee Webchat Push] Pesan uji coba diterima dari Shopee Console (#{event_type})"
  end

  def raw_message_text(data)
    if data['content'].is_a?(Hash)
      data.dig('content', 'text').presence || data.dig('content', 'image_url').presence
    else
      data['text'] || data['content']
    end
  end

  def resolve_contact_name(sender_id, data)
    data['from_name'].presence || data['buyer_name'].presence || default_contact_name(sender_id, data)
  end

  def default_contact_name(sender_id, data)
    return 'Shopee Console Tester' if sender_id.to_s.include?('shopee') || data['type'] == 'notification'

    "Shopee Buyer #{sender_id}"
  end

  def set_contact(sender_id, data)
    contact_attributes = {
      name: resolve_contact_name(sender_id, data),
      additional_attributes: {
        shopee_user_id: sender_id,
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
        type: 'shopee_chat',
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
