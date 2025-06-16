class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_super_admin!
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  # Skip tenant scoped checks for super admins
  skip_before_action :set_current_tenant

  layout 'admin'

  def index
    raise
    @users = User.all.order(:first_name, :last_name)
    @users = @users.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
                         "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @users = @users.where(super_admin: true) if params[:filter] == 'super_admins'
    @users = @users.where(active: params[:status] == 'active') if params[:status].present?
  end

  def show
    @user_tenants = @user.tenant_users.includes(:tenant)
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'User updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user.can_be_deleted?
      @user.destroy
      redirect_to admin_users_path, notice: 'User deleted successfully.'
    else
      redirect_to admin_user_path(@user), alert: 'Cannot delete user with existing data.'
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email, :active, :super_admin)
  end

  def ensure_super_admin!
    unless current_user.super_admin?
      redirect_to root_path, alert: 'Access denied. Super admin privileges required.'
    end
  end
end
