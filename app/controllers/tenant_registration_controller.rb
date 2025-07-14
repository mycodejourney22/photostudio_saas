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

    @user.skip_confirmation!

    # Validate both models before attempting to save
    tenant_valid = @tenant.valid?
    user_valid = @user.valid?

    if tenant_valid && user_valid
      ActiveRecord::Base.transaction do
        @tenant.save!
        @user.save!

        # Create tenant-user relationship as owner
        @tenant.tenant_users.create!(
          user: @user,
          role: 'owner',
          active: true
        )

        # Send verification email (uncomment when ready)
        TenantMailer.verification_email(@tenant).deliver_now

        redirect_to tenant_registration_success_path(token: @tenant.verification_token),
                    notice: 'Studio created! Check your email to verify your account.'
        return # Important: exit the method here
      end
    else
      # Merge errors for unified display
      @errors = []
      @errors += @tenant.errors.full_messages if @tenant.errors.any?
      @errors += @user.errors.full_messages if @user.errors.any?

      Rails.logger.debug "Tenant errors: #{@tenant.errors.full_messages}"
      Rails.logger.debug "User errors: #{@user.errors.full_messages}"

      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Record invalid: #{e.message}"
    @errors = [e.message]
    render :new, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "Unexpected error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @errors = ["An unexpected error occurred. Please try again."]
    render :new, status: :unprocessable_entity
  end

  def verify
    @tenant = Tenant.find_by(verification_token: params[:token])

    if @tenant&.pending?
      @tenant.verify!

      # Setup tenant data (optional)
      # TenantSetupJob.perform_async(@tenant.id)

      # Send welcome email
      # TenantMailer.welcome_email(@tenant).deliver_now

      # Instead of redirecting to subdomain, show verification success page
      render :verified
    else
      redirect_to new_tenant_registration_path,
                  alert: 'Invalid or expired verification link.'
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
    params.require(:tenant).permit(
      :name,
      :subdomain,
      :email,
      :plan_type,
      owner: [:first_name, :last_name, :email, :password]
    )
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :phone)
  end
end
