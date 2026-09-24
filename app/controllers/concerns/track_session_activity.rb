module TrackSessionActivity
  extend ActiveSupport::Concern

  included do
    after_action :update_session_activity
  end

  private

  def update_session_activity
    # Skip for devise controllers to prevent method clashes (e.g. resource_class) in auth/super_admin flows
    return if devise_controller?
    return unless current_user
    return if request.headers['client'].blank?

    UserSessionTrackingService.new(
      user: current_user,
      request: request,
      client_id: request.headers['client']
    ).update_activity!
  rescue StandardError => e
    Rails.logger.warn "Session activity update failed: #{e.message}"
  end
end
