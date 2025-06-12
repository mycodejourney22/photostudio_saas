# app/controllers/users/passwords_controller.rb
class Users::PasswordsController < Devise::PasswordsController
  include TenantScoped

  layout 'public'

  # GET /users/password/new
  def new
    super
  end

  # POST /users/password
  def create
    super
  end

  # GET /users/password/edit?reset_password_token=abcdef
  def edit
    super
  end

  # PATCH/PUT /users/password
  def update
    super
  end

  protected

  def after_resetting_password_path_for(resource)
    dashboard_path
  end
end
