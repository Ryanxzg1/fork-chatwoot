# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_lazada
#
#  id                       :bigint           not null, primary key
#  access_token             :string           not null
#  app_key                  :string           not null
#  app_secret               :string           not null
#  environment              :string           default("sandbox"), not null
#  expires_at               :datetime         not null
#  provider_name            :string           default("Lazada")
#  refresh_token            :string           not null
#  refresh_token_expires_at :datetime         not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :integer          not null
#  seller_id                :string           not null
#
# Indexes
#
#  index_channel_lazada_on_account_id_and_seller_id  (account_id,seller_id) UNIQUE
#  index_channel_lazada_on_seller_id                 (seller_id) UNIQUE
#
class Channel::Lazada < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_lazada'

  EDITABLE_ATTRS = %i[
    seller_id
    app_key
    app_secret
    access_token
    refresh_token
    expires_at
    refresh_token_expires_at
    environment
  ].freeze

  if Chatwoot.encryption_configured?
    encrypts :app_secret
    encrypts :access_token
    encrypts :refresh_token
  end

  AUTHORIZATION_ERROR_THRESHOLD = 2

  validates :seller_id, presence: true, uniqueness: true
  validates :app_key, presence: true
  validates :app_secret, presence: true
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :expires_at, presence: true
  validates :refresh_token_expires_at, presence: true
  validates :environment, inclusion: { in: %w[sandbox production] }

  def name
    'Lazada'
  end

  def client
    @client ||= Lazada::Client.new(channel: self)
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
