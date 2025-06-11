class Admin::BrandingController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_branding

  def show
    respond_to do |format|
      format.html
      format.json { render json: BrandingSerializer.new(@branding).serializable_hash }
    end
  end

  def edit
  end

  def update
    if @branding.update(branding_params)
      BrandingCacheJob.perform_async(current_tenant.id)

      respond_to do |format|
        format.html { redirect_to admin_branding_path, notice: 'Branding updated successfully.' }
        format.json { render json: BrandingSerializer.new(@branding).serializable_hash }
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.json { render json: { errors: @branding.errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_branding
    @branding = current_tenant.branding || current_tenant.build_branding
  end

  def branding_params
    params.require(:branding).permit(
      :primary_color, :secondary_color, :font_family,
      :custom_domain, :welcome_message, :logo, :favicon
    )
  end
end

# ================================================================
# API CONTROLLERS
# ================================================================

# app/controllers/api/base_controller.rb
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
