# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
class SuperAdmin::ApplicationController < Administrate::ApplicationController
  include ActionView::Helpers::TagHelper
  include ActionView::Context
  include SuperAdmin::NavigationHelper

  helper_method :render_vue_component, :settings_open?, :settings_pages
  # authenticiation done via devise : SuperAdmin Model
  before_action :authenticate_super_admin!
  before_action :set_dashboard

  # Override this value to specify the number of elements to display at a time
  # on index pages. Defaults to 20.
  # def records_per_page
  #   params[:per_page] || 20
  # end

  def order
    @order ||= Administrate::Order.new(
      params.fetch(resource_name, {}).fetch(:order, 'id'),
      params.fetch(resource_name, {}).fetch(:direction, 'desc')
    )
  end

  def destroy
    if requested_resource.destroy
      destroy_success_response
    else
      destroy_failure_response
    end
  end

  private

  def destroy_success_response
    notice = translate_with_resource('destroy.success')
    respond_to do |format|
      format.html do
        flash[:notice] = notice
        redirect_to after_resource_destroyed_path(requested_resource)
      end
      format.json do
        render json: { success: true, message: notice, redirect_url: safe_resource_index_url }, status: :ok
      end
    end
  end

  def destroy_failure_response
    error = requested_resource.errors.full_messages.join('<br/>')
    respond_to do |format|
      format.html do
        flash[:error] = error
        redirect_to after_resource_destroyed_path(requested_resource)
      end
      format.json do
        render json: { success: false, message: error }, status: :unprocessable_entity
      end
    end
  end

  def safe_resource_index_url
    polymorphic_path([namespace, resource_class])
  rescue StandardError
    nil
  end

  def set_dashboard
    @dashboard ||= dashboard if respond_to?(:dashboard, true)
  rescue NameError
    nil
  end

  def render_vue_component(component_name, props = {})
    html_options = {
      id: 'app',
      data: {
        component_name: component_name,
        props: props.to_json
      }
    }
    content_tag(:div, '', html_options)
  end

  def invalid_action_perfomed
    # rubocop:disable Rails/I18nLocaleTexts
    flash[:error] = 'Invalid action performed'
    # rubocop:enable Rails/I18nLocaleTexts
    redirect_back(fallback_location: root_path)
  end
end
