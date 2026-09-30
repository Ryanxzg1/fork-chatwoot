class ContactDrop < BaseDrop
  def name
    @obj.try(:name).try(:split).try(:map, &:capitalize).try(:join, ' ')
  end

  def email
    @obj.try(:email)
  end

  def phone_number
    @obj.try(:phone_number)
  end

  def first_name
    @obj.try(:name).try(:split).try(:first).try(:capitalize)
  end

  def last_name
    @obj.try(:name).try(:split).try(:last).try(:capitalize) if @obj.try(:name).try(:split).try(:size) > 1
  end

  def custom_attribute
    custom_attributes = @obj.try(:custom_attributes) || {}
    custom_attributes.transform_keys(&:to_s)
  end

  def identifier
    @obj.try(:identifier)
  end

  def live_chat_hash(website_token = nil)
    return '' if @obj.try(:identifier).blank?
    return '' unless @obj.try(:account).present?

    web_widget = if website_token.present?
                   @obj.account.web_widgets.find_by(website_token: website_token)
                 else
                   @obj.account.web_widgets.where(hmac_mandatory: true).first ||
                     @obj.account.web_widgets.where.not(hmac_token: [nil, '']).first ||
                     @obj.account.web_widgets.first
                 end
    return '' unless web_widget&.hmac_token.present?

    OpenSSL::HMAC.hexdigest('sha256', web_widget.hmac_token, @obj.identifier.to_s)
  end
end
