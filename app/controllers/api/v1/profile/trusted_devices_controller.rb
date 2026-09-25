class Api::V1::Profile::TrustedDevicesController < Api::BaseController
  def destroy
    head :not_found
  end
end
