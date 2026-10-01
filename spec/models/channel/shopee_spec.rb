# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::Shopee, type: :model do
  let(:account) { create(:account) }
  let(:shopee_channel) do
    described_class.create!(
      account: account,
      shop_id: '123456',
      partner_id: '999999',
      partner_key: 'test_partner_key',
      access_token: 'initial_access_token',
      refresh_token: 'initial_refresh_token',
      expires_at: 4.hours.from_now,
      refresh_token_expires_at: 30.days.from_now,
      environment: 'sandbox'
    )
  end

  describe 'validations' do
    it 'validates presence of required attributes' do
      channel = described_class.new
      expect(channel).not_to be_valid
      expect(channel.errors[:shop_id]).to include("can't be blank")
      expect(channel.errors[:partner_id]).to include("can't be blank")
      expect(channel.errors[:partner_key]).to include("can't be blank")
      expect(channel.errors[:access_token]).to include("can't be blank")
      expect(channel.errors[:refresh_token]).to include("can't be blank")
    end

    it 'validates global uniqueness of shop_id across accounts' do
      other_account = create(:account)
      duplicate = described_class.new(
        account: other_account,
        shop_id: shopee_channel.shop_id,
        partner_id: '999999',
        partner_key: 'test_partner_key',
        access_token: 'token',
        refresh_token: 'refresh',
        expires_at: 4.hours.from_now,
        refresh_token_expires_at: 30.days.from_now
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:shop_id]).to include('has already been taken')
    end
  end

  describe '#name' do
    it 'returns Shopee' do
      expect(shopee_channel.name).to eq('Shopee')
    end
  end

  describe '#token_expired?' do
    it 'returns false when token is still valid' do
      expect(shopee_channel.token_expired?).to be false
    end

    it 'returns true when token expires within 5 minutes' do
      shopee_channel.expires_at = 3.minutes.from_now
      expect(shopee_channel.token_expired?).to be true
    end
  end

  describe 'Shopee::Client signature & auth_url' do
    it 'generates correct authorization URL' do
      url = Shopee::Client.authorization_url(
        partner_id: '123',
        partner_key: 'secret',
        redirect_url: 'https://example.com/callback',
        environment: 'sandbox'
      )
      expect(url).to include('https://openplatform.sandbox.test-stable.shopee.sg/api/v2/shop/auth_partner')
      expect(url).to include('partner_id=123')
      expect(url).to include('redirect=https%3A%2F%2Fexample.com%2Fcallback')
      expect(url).to include('sign=')
    end
  end
end
