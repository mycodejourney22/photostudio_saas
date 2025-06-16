class Admin::Setup::StaffMembersController < Admin::Setup::BaseController
  before_action :set_tenant_context
  before_action :set_staff_member, only: [:show, :edit, :update, :destroy, :toggle_status, :reset_password]

  def index
    @staff_members = @tenant.staff_members.includes(:user).order(:role, :first_name)
    @staff_members = @staff_members.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
                                         "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @staff_members = @staff_members.where(role: params[:role]) if params[:role].present?
    @staff_members = @staff_members.where(active: params[:status] == 'active') if params[:status].present?
  end

  def new
    @staff_member = @tenant.staff_members.build
    @available_roles = StaffMember::AVAILABLE_ROLES
  end

  def create
    @staff_member = @tenant.staff_members.build(staff_member_params)

    if @staff_member.save
      handle_user_creation if params[:staff_member][:create_login_account] == '1'
      redirect_to admin_setup_staff_members_path, notice: 'Staff member created successfully.'
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_roles = StaffMember::AVAILABLE_ROLES
  end

  def show
  end

  def reset_password
  end

  def update
    if @staff_member.update(staff_member_params)
      handle_user_creation if params[:staff_member][:create_login_account] == '1' && @staff_member.user.blank?
      redirect_to admin_setup_staff_members_path, notice: 'Staff member updated successfully.'
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @staff_member.can_be_deleted?
      @staff_member.destroy
      redirect_to admin_setup_staff_members_path, notice: 'Staff member removed successfully.'
    else
      redirect_to admin_setup_staff_members_path, alert: 'Cannot delete staff member with existing appointments or sales.'
    end
  end

  def toggle_status
    @staff_member.update(active: !@staff_member.active?)
    status = @staff_member.active? ? 'activated' : 'deactivated'
    redirect_to admin_setup_staff_members_path, notice: "Staff member #{status} successfully."
  end

  def invite
    @staff_member = @tenant.staff_members.build
  end

  def send_invitation
    @staff_member = @tenant.staff_members.build(invitation_params)
    @staff_member.has_login = true

    if @staff_member.save
      # StaffInvitationMailer.invite(@staff_member, current_user).deliver_now
      redirect_to admin_setup_staff_members_path, notice: 'Invitation sent successfully.'
    else
      render :invite, status: :unprocessable_entity
    end
  end

  private

  def set_staff_member
    @staff_member = @tenant.staff_members.find(params[:id])
  end

  def staff_member_params
    params.require(:staff_member).permit(
      :first_name, :last_name, :email, :phone, :role,
      :hourly_rate, :hire_date, :notes, :has_login,
      skills: [], metadata: {}
    )
  end

  def invitation_params
    params.require(:staff_member).permit(:first_name, :last_name, :email, :role)
  end

  def handle_user_creation
    return if @staff_member.user.present?

    password = SecureRandom.alphanumeric(12)
    user = User.create!(
      email: @staff_member.email,
      first_name: @staff_member.first_name,
      last_name: @staff_member.last_name,
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current
    )

    @tenant.tenant_users.create!(
      user: user,
      role: determine_tenant_role(@staff_member.role)
    )

    @staff_member.update!(user: user)
  end

  def determine_tenant_role(staff_role)
    case staff_role
    when 'owner' then 'owner'
    when 'manager' then 'admin'
    else 'staff'
    end
  end
end
