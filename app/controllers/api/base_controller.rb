class Api::BaseController < ApplicationController
  include TenantScoped

  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_user!

  respond_to :json

  private

  def authenticate_api_user!
    token = request.headers['Authorization']&.remove('Bearer ')
    return render_unauthorized unless token

    @current_user = User.joins(:api_keys).find_by(api_keys: { token: token, active: true })
    render_unauthorized unless @current_user
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end

  def render_validation_errors(resource)
    render json: {
      error: 'Validation failed',
      details: resource.errors.full_messages
    }, status: :unprocessable_entity
  end
end
