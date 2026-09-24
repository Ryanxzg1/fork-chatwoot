dash = @dashboard || (dashboard if respond_to?(:dashboard, true))

json.resources resources do |resource|
  json.id resource.id
  json.dashboard_display_name dash.display_resource(resource)
end
