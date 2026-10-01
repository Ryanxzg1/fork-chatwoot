# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_tokopedia
#
#  id                       :bigint           not null, primary key
#  access_token             :string           not null
#  client_id                :string           not null
#  client_secret            :string           not null
#  environment              :string           default("sandbox"), not null
#  expires_at               :datetime         not null
#  provider_name            :string           default("Tokopedia")
#  refresh_token            :string           not null
#  refresh_token_expires_at :datetime         not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :integer          not null
#  shop_id                  :string           not null
#
# Indexes
#
#  index_channel_tokopedia_on_account_id_and_shop_id  (account_id,shop_id) UNIQUE
#  index_channel_tokopedia_on_shop_id                 (shop_id) UNIQUE
#
class Channel::Tokopedia < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_tokopedia'

  EDITABLE_ATTRS = %i[
    shop_id
    client_id
    client_secret
    access_token
    refresh_token
    expires_at
    refresh_token_expires_at
    environment
  ].freeze

  if Chatwoot.encryption_configured?
    encrypts :client_secret
    encrypts :access_token
    encrypts :refresh_token
  end

  AUTHORIZATION_ERROR_THRESHOLD = 2

  validates :shop_id, presence: true, uniqueness: true
  validates :client_id, presence: true
  validates :client_secret, presence: true
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :expires_at, presence: true
  validates :refresh_token_expires_at, presence: true
  validates :environment, inclusion: { in: %w[sandbox production] }

  def name
    'Tokopedia'
  end

  def client
    @client ||= Tokopedia::Client.new(channel: self)
  end

  def token_expired?
    expires_at <= 5.minutes.from_now
  end

  def refresh_token_expired?
    refresh_token_expires_at <= Time.current
  end

  def refresh_access_token!
    client.refresh_access_token!
  end
end
