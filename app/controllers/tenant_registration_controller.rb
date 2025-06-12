# app/controllers/tenant_registration_controller.rb
class TenantRegistrationController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_tenant
  layout 'public'


  def new
    @tenant = Tenant.new
    @user = User.new
  end

  def create
    @tenant = Tenant.new(tenant_params)
    @user = User.new(user_params)

    ActiveRecord::Base.transaction do
      if @tenant.save && @user.save
        # Create tenant-user relationship as owner
        @tenant.tenant_users.create!(
          user: @user,
          role: 'owner',
          active: true
        )

        # Send verification email
        # TenantMailer.verification_email(@tenant).deliver_now

        redirect_to tenant_registration_success_path(token: @tenant.verification_token),
                    notice: 'Studio created! Check your email to verify your account.'
      else
        # Merge errors for unified display
        @errors = @tenant.errors.full_messages + @user.errors.full_messages
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @errors = [e.message]
    render :new, status: :unprocessable_entity
  end

  def verify
    @tenant = Tenant.find_by(verification_token: params[:token])

    if @tenant&.pending?
      @tenant.update!(status: 'active', verified_at: Time.current)
      TenantSetupJob.perform_async(@tenant.id)

      redirect_to new_user_session_url(subdomain: @tenant.subdomain),
                  notice: 'Studio verified! You can now sign in.'
    else
      redirect_to new_tenant_registration_path, alert: 'Invalid or expired verification link.'
    end
  end

  def success
    @tenant = Tenant.find_by(verification_token: params[:token])
    redirect_to new_tenant_registration_path unless @tenant
  end

  def check_subdomain
    available = !Tenant.exists?(subdomain: params[:subdomain])
    render json: { available: available }
  end

  private

  def tenant_params
    params.require(:tenant).permit(:name, :subdomain, :email, :plan_type)
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :phone)
  end
end
