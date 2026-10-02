# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::LazadaEventsJob do
  let(:account) { create(:account) }
  let(:lazada_channel) do
    Channel::Lazada.create!(
      account: account,
      seller_id: 'seller_12345',
      app_key: 'test_key',
      app_secret: 'test_secret',
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      expires_at: 4.hours.from_now,
      refresh_token_expires_at: 30.days.from_now,
      environment: 'sandbox'
    )
  end
  let!(:inbox) { create(:inbox, account: account, channel: lazada_channel) }

  it 'enqueues on default queue' do
    expect(described_class.new.queue_name).to eq('default')
  end

  it 'delegates to Lazada::IncomingMessageService when signature is valid' do
    params = { 'seller_id' => 'seller_12345', 'data' => { 'content' => 'Halo Lazada' } }
    raw_post = params.to_json
    signature = OpenSSL::HMAC.hexdigest('sha256', lazada_channel.app_secret, raw_post).upcase

    service_double = instance_double(Lazada::IncomingMessageService, perform: true)
    expect(Lazada::IncomingMessageService).to receive(:new).with(
      inbox: inbox,
      params: hash_including('seller_id' => 'seller_12345')
    ).and_return(service_double)

    described_class.new.perform(params: params, raw_post: raw_post, signature: signature)
  end

  it 'rejects webhook when channel is production and signature is blank' do
    lazada_channel.update!(environment: 'production')
    params = { 'seller_id' => 'seller_12345', 'data' => { 'content' => 'Halo Lazada' } }
    raw_post = params.to_json

    expect(Lazada::IncomingMessageService).not_to receive(:new)
    described_class.new.perform(params: params, raw_post: raw_post, signature: '')
  end
end
