# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('lib/sidekiq_current_sanitizer')

RSpec.describe SidekiqCurrentSanitizer do
  subject(:middleware) { described_class.new }

  let(:worker) { instance_double(ApplicationJob) }
  let(:job) { { 'class' => 'TestJob', 'jid' => '123' } }
  let(:queue) { 'default' }

  before do
    allow(Current).to receive(:reset)
  end

  it 'calls Current.reset when job completes successfully' do
    yielded = false
    middleware.call(worker, job, queue) do
      yielded = true
    end

    expect(yielded).to be true
    expect(Current).to have_received(:reset)
  end

  it 'calls Current.reset even if job raises an error' do
    expect do
      middleware.call(worker, job, queue) do
        raise StandardError, 'Job failed'
      end
    end.to raise_error(StandardError, 'Job failed')

    expect(Current).to have_received(:reset)
  end
end
