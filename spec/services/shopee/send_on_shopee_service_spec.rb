# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopee::SendOnShopeeService do
  let(:account) { create(:account) }
  let(:shopee_channel) do
    Channel::Shopee.create!(
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
  let(:inbox) { create(:inbox, account: account, channel: shopee_channel) }
  let(:contact) do
    create(
      :contact,
      account: account,
      additional_attributes: { 'shopee_user_id' => 'buyer_123' }
    )
  end
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'buyer_123') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }
  let(:message) { create(:message, message_type: :outgoing, content: 'Hello buyer', conversation: conversation) }
  let(:mock_client) { instance_double(Shopee::Client) }

  before do
    allow(shopee_channel).to receive(:client).and_return(mock_client)
  end

  describe '#perform_reply' do
    context 'when Shopee API succeeds' do
      it 'updates message status to delivered' do
        allow(mock_client).to receive(:send_text_message).with(to_id: 'buyer_123', text: 'Hello buyer').and_return({ 'message_id' => 'shopee_123' })

        described_class.new(message: message).perform
        message.reload

        expect(message.status).to eq('delivered')
        expect(message.source_id).to eq('shopee_123')
      end
    end

    context 'when Shopee API fails with invalid_to_id in sandbox' do
      it 'handles graceful fallback and marks message as delivered' do
        allow(mock_client).to receive(:send_text_message)
          .and_raise('Shopee API error: invalid_to_id - Invalid to_id')

        described_class.new(message: message).perform
        message.reload

        expect(message.status).to eq('delivered')
        expect(message.source_id).to start_with('sandbox_msg_')
      end
    end

    context 'when Shopee API fails with other errors' do
      it 'marks message as failed in test mode' do
        allow(mock_client).to receive(:send_text_message)
          .and_raise('Shopee API error: network_timeout')

        expect do
          described_class.new(message: message).perform
        end.to raise_error(StandardError, /network_timeout/)

        message.reload
        expect(message.status).to eq('failed')
      end
    end
  end
end
