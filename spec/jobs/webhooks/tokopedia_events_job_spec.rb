# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::TokopediaEventsJob do
  let(:account) { create(:account) }
  let(:tokopedia_channel) do
    Channel::Tokopedia.create!(
      account: account,
      shop_id: '12345678',
      client_id: 'test_client_id',
      client_secret: 'test_secret',
      access_token: 'test_access_token',
      refresh_token: 'test_refresh_token',
      expires_at: 4.hours.from_now,
      refresh_token_expires_at: 30.days.from_now,
      environment: 'sandbox'
    )
  end
  let!(:inbox) { create(:inbox, account: account, channel: tokopedia_channel) }

  it 'enqueues on default queue' do
    expect(described_class.new.queue_name).to eq('default')
  end

  it 'delegates to Tokopedia::IncomingMessageService when signature is valid' do
    params = { 'shop_id' => '12345678', 'data' => { 'message' => 'Halo gan' } }
    raw_post = params.to_json
    signature = OpenSSL::HMAC.hexdigest('sha256', tokopedia_channel.client_secret, raw_post)

    service_double = instance_double(Tokopedia::IncomingMessageService, perform: true)
    expect(Tokopedia::IncomingMessageService).to receive(:new).with(
      inbox: inbox,
      params: hash_including('shop_id' => '12345678')
    ).and_return(service_double)

    described_class.new.perform(params: params, raw_post: raw_post, signature: signature)
  end

  it 'rejects webhook when channel is production and signature is blank' do
    tokopedia_channel.update!(environment: 'production')
    params = { 'shop_id' => '12345678', 'data' => { 'message' => 'Halo gan' } }
    raw_post = params.to_json

    expect(Tokopedia::IncomingMessageService).not_to receive(:new)
    described_class.new.perform(params: params, raw_post: raw_post, signature: '')
  end
end
