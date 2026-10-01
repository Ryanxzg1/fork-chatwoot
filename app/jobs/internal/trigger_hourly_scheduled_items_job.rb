class Internal::TriggerHourlyScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channels::Whatsapp::HealthSyncSchedulerJob.perform_later
    Shopee::TokenRefreshJob.perform_later
  end
end

