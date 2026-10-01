# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopee::IncomingMessageService do
  let(:account) { create(:account) }
  let(:shopee_channel) do
    Channel::Shopee.create!(
      account: account,
      shop_id: '227929373',
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

  describe '#perform' do
    context 'when buyer sends a valid text message' do
      let(:params) do
        {
          'shop_id' => '227929373',
          'data' => {
            'from_id' => 'buyer_999',
            'from_name' => 'Budi Tester',
            'message_id' => 'msg_1001',
            'content' => { 'text' => 'Halo apakah barang ready?' }
          }
        }
      end

      it 'creates contact, conversation, and incoming message' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.to change(Conversation, :count).by(1)
           .and change(Message, :count).by(1)

        message = inbox.messages.last
        expect(message.content).to eq('Halo apakah barang ready?')
        expect(message.message_type).to eq('incoming')
        expect(message.sender.name).to eq('Budi Tester')
      end
    end

    context 'when receiving Shopee Console Push Test Data in sandbox' do
      let(:params) do
        {
          'code' => 10,
          'shop_id' => '399917162',
          'msg_id' => 'jARSWzxxuJBQencLPyqiulqFsHHsUKEQ',
          'data' => {
            'type' => 'notification',
            'content' => {
              'user_id' => 399_936_739,
              'type' => 'mark_as_replied',
              'from_id' => 0
            }
          }
        }
      end

      it 'creates an informative test message in sandbox mode' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.to change(Conversation, :count).by(1)
           .and change(Message, :count).by(1)

        message = inbox.messages.last
        expect(message.content).to include('[Shopee Webchat Push]')
        expect(message.sender.name).to eq('Shopee Console Tester')
      end
    end

    context 'when sender is the shop itself' do
      let(:params) do
        {
          'shop_id' => '227929373',
          'data' => {
            'from_id' => '227929373',
            'content' => { 'text' => 'Echo message from shop' }
          }
        }
      end

      it 'ignores the message' do
        expect do
          described_class.new(inbox: inbox, params: params).perform
        end.not_to change(Message, :count)
      end
    end
  end
end
