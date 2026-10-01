# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_shopee
#
#  id                       :bigint           not null, primary key
#  access_token             :string           not null
#  environment              :string           default("sandbox"), not null
#  expires_at               :datetime         not null
#  partner_key              :string           not null
#  provider_name            :string           default("Shopee")
#  refresh_token            :string           not null
#  refresh_token_expires_at :datetime         not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :integer          not null
#  partner_id               :string           not null
#  shop_id                  :string           not null
#
# Indexes
#
#  index_channel_shopee_on_account_id_and_shop_id  (account_id,shop_id) UNIQUE
#  index_channel_shopee_on_shop_id                 (shop_id) UNIQUE
#
class Channel::Shopee < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_shopee'

  EDITABLE_ATTRS = %i[
    shop_id
    partner_id
    partner_key
    access_token
    refresh_token
    expires_at
    refresh_token_expires_at
    environment
  ].freeze

  if Chatwoot.encryption_configured?
    encrypts :partner_key
    encrypts :access_token
    encrypts :refresh_token
  end

  AUTHORIZATION_ERROR_THRESHOLD = 2
  DEFAULT_SANDBOX_PUSH_KEY = 'aaaaaaaaaaaaaaforl6risqqtpy0m3di2bowmo2x6z1ys8n36ptzkcgou03mtmzr'

  validates :shop_id, presence: true, uniqueness: true
  validates :partner_id, presence: true
  validates :partner_key, presence: true
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :expires_at, presence: true
  validates :refresh_token_expires_at, presence: true
  validates :environment, inclusion: { in: %w[sandbox production] }

  def name
    'Shopee'
  end

  def sandbox_push_key
    ENV.fetch('SHOPEE_SANDBOX_PUSH_KEY', DEFAULT_SANDBOX_PUSH_KEY)
  end

  def client
    @client ||= Shopee::Client.new(channel: self)
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
