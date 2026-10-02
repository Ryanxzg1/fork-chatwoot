# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::IncomingMessageService do
  let(:account) { create(:account) }
  let(:lazada_channel) do
    Channel::Lazada.create!(
      account: account,
      seller_id: 'seller_12345',
      app_key: 'test_app_key',
      app_secret: 'test_app_secret',
      access_token: 'initial_access_token',
      refresh_token: 'initial_refresh_token',
      expires_at: 4.hours.from_now,
      refresh_token_expires_at: 30.days.from_now,
      environment: 'sandbox'
    )
  end
  let(:inbox) { create(:inbox, account: account, channel: lazada_channel) }

  describe '#perform' do
    context 'when buyer sends a valid text message' do
      let(:params) do
        {
          'seller_id' => 'seller_12345',
          'data' => {
            'buyer_id' => 'buyer_777',
            'buyer_name' => 'Ahmad Lazada',
            'message_id' => 'laz_msg_5001',
            'content' => 'Bisa kirim hari ini kak?'
          }
        }
      end

      it 'creates contact, conversation, and incoming message' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.to change(Conversation, :count).by(1)
           .and change(Message, :count).by(1)

        message = inbox.messages.last
        expect(message.content).to eq('Bisa kirim hari ini kak?')
        expect(message.message_type).to eq('incoming')
        expect(message.sender.name).to eq('Ahmad Lazada')
        expect(inbox.contacts.last.additional_attributes['lazada_user_id']).to eq('buyer_777')
      end

      it 'does not create duplicate message if message_id already exists' do
        described_class.new(inbox: inbox, params: params).perform

        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.not_to change(Message, :count)
      end
    end

    context 'when content is a JSON-encoded string with txt key' do
      let(:params) do
        {
          'seller_id' => 'seller_12345',
          'data' => {
            'buyer_id' => 'buyer_777',
            'message_id' => 'laz_msg_5002',
            'content' => '{"txt":"Ada garansi resmi tidak?"}'
          }
        }
      end

      it 'extracts and parses txt properly' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.to change(Message, :count).by(1)

        message = inbox.messages.last
        expect(message.content).to eq('Ada garansi resmi tidak?')
      end
    end

    context 'when sender is the seller itself (echo)' do
      let(:params) do
        {
          'seller_id' => 'seller_12345',
          'data' => {
            'buyer_id' => 'seller_12345',
            'content' => 'Echo message from seller'
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
          'seller_id' => 'seller_12345',
          'data' => 'ping_from_lazada_test'
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
          'seller_id' => 'seller_12345',
          'data' => {
            'buyer_id' => 'buyer_777',
            'id' => 'custom_laz_id_101',
            'content' => 'Testing id candidate'
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
