# app/controllers/users/passwords_controller.rb
class Users::PasswordsController < Devise::PasswordsController
  skip_before_action :authenticate_user!, only: [:new, :create, :edit, :update]

  layout 'public'

  # GET /users/password/edit?reset_password_token=abcdef
  def edit
    @reset_password_token = params[:reset_password_token]

    if @reset_password_token.present?
      # Find the user manually using our custom logic
      reset_password_token = Devise.token_generator.digest(User, :reset_password_token, @reset_password_token)
      @user = User.find_by(reset_password_token: reset_password_token)

      if @user
        # Set tenant context
        if @user.primary_tenant
          @current_tenant = @user.primary_tenant
          ActsAsTenant.current_tenant = @current_tenant
        end

        # Create a new user object for the form (don't use the found user)
        self.resource = User.new
        resource.reset_password_token = @reset_password_token
      else
        redirect_to new_user_password_path, alert: 'Invalid or expired password reset link.'
        return
      end
    else
      redirect_to new_user_password_path, alert: 'Invalid password reset link.'
      return
    end
  end

  # PUT /users/password
  def update
    @reset_password_token = params[:user][:reset_password_token]

    if @reset_password_token.present?
      # Find the actual user
      reset_password_token = Devise.token_generator.digest(User, :reset_password_token, @reset_password_token)
      @user = User.find_by(reset_password_token: reset_password_token)

      if @user
        # Set tenant context
        if @user.primary_tenant
          @current_tenant = @user.primary_tenant
          ActsAsTenant.current_tenant = @current_tenant
        end

        # Check if token is expired
        if @user.reset_password_sent_at && @user.reset_password_sent_at < Devise.reset_password_within.ago
          redirect_to new_user_password_path, alert: 'Password reset link has expired. Please request a new one.'
          return
        end

        # Validate password
        password = params[:user][:password]
        password_confirmation = params[:user][:password_confirmation]

        if password.blank?
          @user.errors.add(:password, "can't be blank")
        elsif password.length < 8
          @user.errors.add(:password, "is too short (minimum is 8 characters)")
        elsif password != password_confirmation
          @user.errors.add(:password_confirmation, "doesn't match Password")
        end

        if @user.errors.empty?
          # Update password manually
          ActsAsTenant.with_tenant(@current_tenant) do
            @user.password = password
            @user.password_confirmation = password_confirmation
            @user.reset_password_token = nil
            @user.reset_password_sent_at = nil

            if @user.save(validate: false) # Skip other validations
              sign_in(@user) # Sign them in
              redirect_to after_resetting_password_path_for(@user)
              return
            else
              @user.errors.add(:base, "Failed to update password. Please try again.")
            end
          end
        end

        # If we get here, there were errors
        self.resource = User.new
        resource.reset_password_token = @reset_password_token
        resource.errors.merge!(@user.errors)
        render :edit, status: :unprocessable_entity
      else
        redirect_to new_user_password_path, alert: 'Invalid or expired password reset link.'
      end
    else
      redirect_to new_user_password_path, alert: 'Invalid password reset link.'
    end
  end

  protected

  def after_resetting_password_path_for(resource)
    if resource.primary_tenant
      tenant = resource.primary_tenant
      if Rails.env.development?
        "http://#{tenant.subdomain}.localhost:3000/dashboard"
      else
        "https://#{tenant.subdomain}.#{Rails.application.config.app_domain}/dashboard"
      end
    else
      new_user_session_path
    end
  end

  private

  def current_tenant
    @current_tenant
  end
end
