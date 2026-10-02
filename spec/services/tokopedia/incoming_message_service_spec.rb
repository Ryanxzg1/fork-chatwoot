# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tokopedia::IncomingMessageService do
  let(:account) { create(:account) }
  let(:tokopedia_channel) do
    Channel::Tokopedia.create!(
      account: account,
      shop_id: '12345678',
      client_id: 'test_client_id',
      client_secret: 'test_client_secret',
      access_token: 'initial_access_token',
      refresh_token: 'initial_refresh_token',
      expires_at: 4.hours.from_now,
      refresh_token_expires_at: 30.days.from_now,
      environment: 'sandbox'
    )
  end
  let(:inbox) { create(:inbox, account: account, channel: tokopedia_channel) }

  describe '#perform' do
    context 'when buyer sends a valid text message' do
      let(:params) do
        {
          'shop_id' => '12345678',
          'data' => {
            'sender_id' => 'buyer_888',
            'sender_name' => 'Siti Tester',
            'msg_id' => 'tkpd_msg_1001',
            'message' => 'Halo apakah barang ready gan?'
          }
        }
      end

      it 'creates contact, conversation, and incoming message' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.to change(Conversation, :count).by(1)
           .and change(Message, :count).by(1)

        message = inbox.messages.last
        expect(message.content).to eq('Halo apakah barang ready gan?')
        expect(message.message_type).to eq('incoming')
        expect(message.sender.name).to eq('Siti Tester')
        expect(inbox.contacts.last.additional_attributes['tokopedia_user_id']).to eq('buyer_888')
      end

      it 'does not create duplicate message if message_id already exists' do
        described_class.new(inbox: inbox, params: params).perform

        # Repeat the same incoming event
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.not_to change(Message, :count)
      end
    end

    context 'when sender is the shop itself (echo)' do
      let(:params) do
        {
          'shop_id' => '12345678',
          'data' => {
            'sender_id' => '12345678',
            'message' => 'Echo message from seller'
          }
        }
      end

      it 'ignores the message' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.not_to change(Message, :count)
      end
    end

    context 'when payload data is a non-hash type (malformed/ping)' do
      let(:params) do
        {
          'shop_id' => '12345678',
          'data' => 'pong_ping_string'
        }
      end

      it 'handles gracefully without raising TypeError' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.not_to change(Message, :count)
      end
    end

    context 'when payload uses id for message identification' do
      let(:params) do
        {
          'shop_id' => '12345678',
          'data' => {
            'sender_id' => 'buyer_888',
            'id' => 'custom_id_999',
            'message' => 'Testing id candidate'
          }
        }
      end

      it 'deduplicates messages properly using id' do
        described_class.new(inbox: inbox, params: params).perform

        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.not_to change(Message, :count)
      end
    end
  end
end
