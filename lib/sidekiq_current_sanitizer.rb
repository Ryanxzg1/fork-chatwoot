# frozen_string_literal: true

# Ensures thread-local Current attributes are cleanly reset after every job execution
# to prevent cross-job state leakage on pooled Sidekiq worker threads.
class SidekiqCurrentSanitizer
  def call(_worker, _job, _queue)
    yield
  ensure
    Current.reset
  end
end
