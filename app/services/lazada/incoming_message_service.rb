# frozen_string_literal: true

class Lazada::IncomingMessageService
  pattr_initialize [:inbox!, :params!]

  # rubocop:disable Metrics/CyclomaticComplexity
  def perform
    return if params.blank?

    data = params.key?('data') ? params['data'] : params
    return unless data.is_a?(Hash)

    sender_id = resolve_sender_id(data)
    return if sender_id.blank?

    # Ignore messages sent by the seller itself (echoes)
    return if sender_id.to_s == inbox.channel.seller_id.to_s

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
    candidate_keys = %w[buyer_id from_id session_id sender_id]
    sender = candidate_keys.filter_map { |k| data[k] }.first || data.dig('content', 'user_id')
    return sender.to_s if sender.present? && sender.to_s != '0'

    # Fallback for Lazada sandbox testing
    'lazada_tester' if inbox.channel.environment == 'sandbox'
  end

  def resolve_message_id(data, sender_id)
    candidate_id_keys = %w[message_id msg_id id]
    msg_id = candidate_id_keys.filter_map { |k| params[k] || data[k] }.first
    return msg_id.to_s if msg_id.present?

    "#{sender_id}_#{Time.current.to_f}"
  end

  def extract_text_content(data)
    content = data['content'] || data['message'] || data['text']
    parse_content_text(content).presence || fallback_sandbox_text(data)
  end

  def parse_content_text(content)
    return if content.blank?

    if content.is_a?(Hash)
      content['txt'] || content['text'] || content['message']
    elsif content.is_a?(String)
      parse_string_content(content)
    end
  end

  def parse_string_content(content)
    parsed = begin
      JSON.parse(content)
    rescue JSON::ParserError
      nil
    end

    if parsed.is_a?(Hash)
      parsed['txt'] || parsed['text'] || parsed['message'] || content
    else
      content
    end
  end

  def fallback_sandbox_text(data)
    return unless inbox.channel.environment == 'sandbox'

    event_type = data['message_type'] || data['template_id'] || 'Lazada Chat'
    "🔔 [Lazada Chat Push] Pesan uji coba diterima dari Lazada Console (#{event_type})"
  end

  def resolve_contact_name(sender_id, data)
    data['buyer_name'].presence || data['from_name'].presence || data['sender_name'].presence || default_contact_name(sender_id, data)
  end

  def default_contact_name(sender_id, data)
    return 'Lazada Tester' if sender_id.to_s.include?('lazada') || data['type'] == 'notification'

    "Lazada Buyer #{sender_id}"
  end

  def set_contact(sender_id, data)
    contact_attributes = {
      name: resolve_contact_name(sender_id, data),
      additional_attributes: {
        lazada_user_id: sender_id,
        seller_id: inbox.channel.seller_id
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
        type: 'lazada_chat',
        seller_id: inbox.channel.seller_id
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
