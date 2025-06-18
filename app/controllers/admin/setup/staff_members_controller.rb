# app/controllers/admin/setup/staff_members_controller.rb
# app/controllers/admin/setup/staff_members_controller.rb
class Admin::Setup::StaffMembersController < Admin::Setup::BaseController
  before_action :set_tenant_context
  before_action :set_staff_member, only: [:show, :edit, :update, :destroy, :toggle_status, :reset_password, :send_password_setup]

  def index
    @staff_members = @tenant.staff_members.includes(:user, :studio_location).order(:role, :first_name)
    @staff_members = @staff_members.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
                                         "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @staff_members = @staff_members.where(role: params[:role]) if params[:role].present?
    @staff_members = @staff_members.where(active: params[:status] == 'active') if params[:status].present?
  end

  def new
    @staff_member = @tenant.staff_members.build
    @available_roles = StaffMember::AVAILABLE_ROLES
    @studio_locations = @tenant.studio_locations.active
  end

  def create
    @staff_member = @tenant.staff_members.build(staff_member_params)

    if @staff_member.save
      if params[:staff_member][:create_login_account] == '1'
        result = handle_user_creation
        if result[:success]
          redirect_to admin_setup_staff_members_path, notice: 'Staff member created successfully. Password setup email sent.'
        else
          redirect_to admin_setup_staff_members_path, alert: "Staff member created but login setup failed: #{result[:error]}"
        end
      else
        redirect_to admin_setup_staff_members_path, notice: 'Staff member created successfully.'
      end
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      @studio_locations = @tenant.studio_locations.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_roles = StaffMember::AVAILABLE_ROLES
    @studio_locations = @tenant.studio_locations.active
  end

  def show
  end

  def reset_password
  end

  def send_password_setup
    if @staff_member.user.present?
      # Use Devise's method to generate token and send our custom email
      send_staff_password_setup_email(@staff_member.user)
      redirect_to admin_setup_staff_members_path, notice: 'Password setup email sent successfully.'
    else
      redirect_to admin_setup_staff_members_path, alert: 'Staff member does not have a user account.'
    end
  end

  def update
    if @staff_member.update(staff_member_params)
      # Handle login account creation if requested and not already created
      if params[:staff_member][:create_login_account] == '1' && @staff_member.user.blank?
        result = handle_user_creation
        if result[:success]
          redirect_to admin_setup_staff_members_path, notice: 'Staff member updated successfully. Password setup email sent.'
        else
          redirect_to admin_setup_staff_members_path, alert: "Staff member updated but login setup failed: #{result[:error]}"
        end
      else
        redirect_to admin_setup_staff_members_path, notice: 'Staff member updated successfully.'
      end
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      @studio_locations = @tenant.studio_locations.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @staff_member.can_be_deleted?
      # Also destroy associated user and tenant_user if they exist
      if @staff_member.user.present?
        tenant_user = @staff_member.user.tenant_users.find_by(tenant: @tenant)
        tenant_user&.destroy

        # Only destroy user if they don't belong to any other tenants
        if @staff_member.user.tenant_users.count == 0
          @staff_member.user.destroy
        end
      end

      @staff_member.destroy
      redirect_to admin_setup_staff_members_path, notice: 'Staff member removed successfully.'
    else
      redirect_to admin_setup_staff_members_path, alert: 'Cannot delete staff member with existing appointments or sales.'
    end
  end

  def toggle_status
    @staff_member.update(active: !@staff_member.active?)

    # Also update user status if user exists
    if @staff_member.user.present?
      @staff_member.user.update(active: @staff_member.active?)
    end

    status = @staff_member.active? ? 'activated' : 'deactivated'
    redirect_to admin_setup_staff_members_path, notice: "Staff member #{status} successfully."
  end

  def invite
    @staff_member = @tenant.staff_members.build
    @available_roles = StaffMember::AVAILABLE_ROLES
    @studio_locations = @tenant.studio_locations.active
  end

  def send_invitation
    @staff_member = @tenant.staff_members.build(invitation_params)
    @staff_member.has_login = true

    if @staff_member.save
      result = handle_user_creation
      if result[:success]
        # StaffInvitationMailer.invite(@staff_member, current_user).deliver_now
        redirect_to admin_setup_staff_members_path, notice: 'Invitation sent successfully.'
      else
        redirect_to admin_setup_staff_members_path, alert: "Invitation created but setup failed: #{result[:error]}"
      end
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      @studio_locations = @tenant.studio_locations.active
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
      :hourly_rate, :hire_date, :notes, :has_login, :studio_location_id,
      skills: [], metadata: {}
    )
  end

  def invitation_params
    params.require(:staff_member).permit(:first_name, :last_name, :email, :role, :studio_location_id)
  end

  def handle_user_creation
    return { success: false, error: "Staff member already has a user account" } if @staff_member.user.present?

    begin
      # Create user without password (they'll set it via email)
      user = User.new(
        email: @staff_member.email,
        first_name: @staff_member.first_name,
        last_name: @staff_member.last_name
      )

      # Set a temporary password that will be changed via reset
      temp_password = SecureRandom.alphanumeric(20)
      user.password = temp_password
      user.password_confirmation = temp_password

      # Save user without sending confirmation (we'll send password setup instead)
      user.skip_confirmation!
      user.save!

      # Create tenant user relationship
      tenant_user = @tenant.tenant_users.create!(
        user: user,
        role: determine_tenant_role(@staff_member.role)
      )

      # Link user to staff member
      @staff_member.update!(user: user)

      # Send password setup email using Devise's proper method
      send_staff_password_setup_email(user)

      { success: true, user: user, tenant_user: tenant_user }
    rescue => e
      Rails.logger.error "Failed to create user for staff member #{@staff_member.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def send_staff_password_setup_email(user)
    # Generate reset password token WITHOUT sending Devise's default email
    raw_token = user.send(:set_reset_password_token)

    # Send ONLY our custom email with tenant-specific URL
    StaffPasswordMailer.password_setup_instructions(user, @tenant, raw_token).deliver_now

    Rails.logger.info "Password setup email sent to #{user.email} with token: #{raw_token}"
  end

  def determine_tenant_role(staff_role)
    case staff_role
    when 'owner' then 'owner'
    when 'manager' then 'admin'
    else 'staff'
    end
  end
end

  def index
    @staff_members = @tenant.staff_members.includes(:user, :studio_location).order(:role, :first_name)
    @staff_members = @staff_members.where("first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ?",
                                         "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @staff_members = @staff_members.where(role: params[:role]) if params[:role].present?
    @staff_members = @staff_members.where(active: params[:status] == 'active') if params[:status].present?
  end

  def new
    @staff_member = @tenant.staff_members.build
    @available_roles = StaffMember::AVAILABLE_ROLES
    @studio_locations = @tenant.studio_locations.active
  end

  def create
    @staff_member = @tenant.staff_members.build(staff_member_params)

    if @staff_member.save
      if params[:staff_member][:create_login_account] == '1'
        result = handle_user_creation
        if result[:success]
          redirect_to admin_setup_staff_members_path, notice: 'Staff member created successfully. Password setup email sent.'
        else
          redirect_to admin_setup_staff_members_path, alert: "Staff member created but login setup failed: #{result[:error]}"
        end
      else
        redirect_to admin_setup_staff_members_path, notice: 'Staff member created successfully.'
      end
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      @studio_locations = @tenant.studio_locations.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_roles = StaffMember::AVAILABLE_ROLES
    @studio_locations = @tenant.studio_locations.active
  end

  def show
  end

  def reset_password
  end

  def send_password_setup
    if @staff_member.user.present?
      # Use our custom mailer instead of Devise's default
      send_staff_password_setup_email(@staff_member.user)
      redirect_to admin_setup_staff_members_path, notice: 'Password setup email sent successfully.'
    else
      redirect_to admin_setup_staff_members_path, alert: 'Staff member does not have a user account.'
    end
  end

  def update
    if @staff_member.update(staff_member_params)
      # Handle login account creation if requested and not already created
      if params[:staff_member][:create_login_account] == '1' && @staff_member.user.blank?
        result = handle_user_creation
        if result[:success]
          redirect_to admin_setup_staff_members_path, notice: 'Staff member updated successfully. Password setup email sent.'
        else
          redirect_to admin_setup_staff_members_path, alert: "Staff member updated but login setup failed: #{result[:error]}"
        end
      else
        redirect_to admin_setup_staff_members_path, notice: 'Staff member updated successfully.'
      end
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      @studio_locations = @tenant.studio_locations.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @staff_member.can_be_deleted?
      # Also destroy associated user and tenant_user if they exist
      if @staff_member.user.present?
        tenant_user = @staff_member.user.tenant_users.find_by(tenant: @tenant)
        tenant_user&.destroy

        # Only destroy user if they don't belong to any other tenants
        if @staff_member.user.tenant_users.count == 0
          @staff_member.user.destroy
        end
      end

      @staff_member.destroy
      redirect_to admin_setup_staff_members_path, notice: 'Staff member removed successfully.'
    else
      redirect_to admin_setup_staff_members_path, alert: 'Cannot delete staff member with existing appointments or sales.'
    end
  end

  def toggle_status
    @staff_member.update(active: !@staff_member.active?)

    # Also update user status if user exists
    if @staff_member.user.present?
      @staff_member.user.update(active: @staff_member.active?)
    end

    status = @staff_member.active? ? 'activated' : 'deactivated'
    redirect_to admin_setup_staff_members_path, notice: "Staff member #{status} successfully."
  end

  def invite
    @staff_member = @tenant.staff_members.build
    @available_roles = StaffMember::AVAILABLE_ROLES
    @studio_locations = @tenant.studio_locations.active
  end

  def send_invitation
    @staff_member = @tenant.staff_members.build(invitation_params)
    @staff_member.has_login = true

    if @staff_member.save
      result = handle_user_creation
      if result[:success]
        # StaffInvitationMailer.invite(@staff_member, current_user).deliver_now
        redirect_to admin_setup_staff_members_path, notice: 'Invitation sent successfully.'
      else
        redirect_to admin_setup_staff_members_path, alert: "Invitation created but setup failed: #{result[:error]}"
      end
    else
      @available_roles = StaffMember::AVAILABLE_ROLES
      @studio_locations = @tenant.studio_locations.active
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
      :hourly_rate, :hire_date, :notes, :has_login, :studio_location_id,
      skills: [], metadata: {}
    )
  end

  def invitation_params
    params.require(:staff_member).permit(:first_name, :last_name, :email, :role, :studio_location_id)
  end

  def handle_user_creation
    return { success: false, error: "Staff member already has a user account" } if @staff_member.user.present?

    begin
      # Create user without password (they'll set it via email)
      user = User.new(
        email: @staff_member.email,
        first_name: @staff_member.first_name,
        last_name: @staff_member.last_name
      )

      # Set a temporary password that will be changed via reset
      temp_password = SecureRandom.alphanumeric(20)
      user.password = temp_password
      user.password_confirmation = temp_password

      # Save user without sending confirmation (we'll send password setup instead)
      user.skip_confirmation!
      user.save!

      # Create tenant user relationship
      tenant_user = @tenant.tenant_users.create!(
        user: user,
        role: determine_tenant_role(@staff_member.role)
      )

      # Link user to staff member
      @staff_member.update!(user: user)

      # Send password setup email using Devise's proper method
      send_staff_password_setup_email(user)

      { success: true, user: user, tenant_user: tenant_user }
    rescue => e
      Rails.logger.error "Failed to create user for staff member #{@staff_member.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def send_staff_password_setup_email(user)
    # Generate reset password token using Devise's method
    raw_token = user.send_reset_password_instructions

    # Send custom email with tenant-specific URL
    StaffPasswordMailer.password_setup_instructions(user, @tenant, raw_token).deliver_now

    Rails.logger.info "Password setup email sent to #{user.email} with token: #{raw_token}"
  end

  def send_password_setup
    if @staff_member.user.present?
      # Use Devise's method to generate token and send our custom email
      send_staff_password_setup_email(@staff_member.user)
      redirect_to admin_setup_staff_members_path, notice: 'Password setup email sent successfully.'
    else
      redirect_to admin_setup_staff_members_path, alert: 'Staff member does not have a user account.'
    end
  end

  def determine_tenant_role(staff_role)
    case staff_role
    when 'owner' then 'owner'
    when 'manager' then 'admin'
    else 'staff'
    end
  end
