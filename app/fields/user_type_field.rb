require 'administrate/field/select'

class UserTypeField < Administrate::Field::Select
  def to_partial_path
    return '/fields/user_type_field/form' if page == :form
    return '/fields/user_type_field/index' if page == :index
    return '/fields/user_type_field/show' if page == :show

    "/fields/select/#{page}"
  end

  def selectable_options
    [
      ['Regular User', nil],
      ['Super Admin', 'SuperAdmin']
    ]
  end
end
