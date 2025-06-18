# app/models/ability.rb - FIXED VERSION
class Ability
  include CanCan::Ability

  def initialize(user, tenant)
    user ||= User.new # guest user (not logged in)
    @tenant = tenant

    if user.persisted? && tenant.present?
      setup_tenant_permissions(user, tenant)
    else
      # Guest permissions (no tenant context)
      setup_guest_permissions
    end
  end

  private

  def setup_tenant_permissions(user, tenant)
    # Get user's role in this specific tenant
    tenant_user = user.tenant_users.find_by(tenant: tenant)
    return setup_guest_permissions unless tenant_user

    case tenant_user.role
    when 'owner'
      setup_owner_permissions(user, tenant)
    when 'admin'
      setup_admin_permissions(user, tenant)
    when 'staff'
      setup_staff_permissions(user, tenant)
    else
      setup_guest_permissions
    end
  end

  def setup_owner_permissions(user, tenant)
    # Owner has full access to everything in their tenant
    can :manage, :all, tenant_id: tenant.id

    # Specifically for expenses
    can :manage, Expense, tenant_id: tenant.id
    can :approve, Expense, tenant_id: tenant.id
    can :reject, Expense, tenant_id: tenant.id

    # Specifically for sales
    can :manage, Sale, tenant_id: tenant.id

    # Can manage tenant settings
    can :manage, Tenant, id: tenant.id
    can :manage, TenantUser, tenant_id: tenant.id
    can :manage, Branding, tenant_id: tenant.id

    # Can manage billing and subscription
    can :manage, :billing
    can :manage, :subscription
    can :view, :analytics
    can :export, :data
  end

  def setup_admin_permissions(user, tenant)
    # Admin can manage most resources but not tenant settings or billing
    can :manage, Appointment, tenant_id: tenant.id
    can :manage, Customer, tenant_id: tenant.id
    can :manage, Studio, tenant_id: tenant.id
    can :manage, StaffMember, tenant_id: tenant.id

    # Sales permissions for admin
    can :manage, Sale, tenant_id: tenant.id

    # Expenses permissions for admin
    can :manage, Expense, tenant_id: tenant.id
    can :approve, Expense, tenant_id: tenant.id
    can :reject, Expense, tenant_id: tenant.id

    # Can manage branding
    can :manage, Branding, tenant_id: tenant.id

    # Can read tenant info but not modify critical settings
    can :read, Tenant, id: tenant.id
    can :read, TenantUser, tenant_id: tenant.id

    # Can view analytics
    can :view, :analytics
    can :export, :data

    # Cannot manage billing or subscription
    cannot :manage, :billing
    cannot :manage, :subscription
    cannot :delete, Tenant
  end

  def setup_staff_permissions(user, tenant)
    staff_member = StaffMember.find_by(user: user, tenant: tenant)
    return setup_guest_permissions unless staff_member

    # Set up general staff permissions first
    setup_general_staff_permissions(user, tenant, staff_member)

    # Then add role-specific permissions
    setup_staff_role_permissions(user, tenant, staff_member)
  end

  def setup_general_staff_permissions(user, tenant, staff_member)
    # Basic permissions that all staff members get
    can :manage, Appointment, tenant_id: tenant.id
    can :read, Customer, tenant_id: tenant.id
    can :create, Customer, tenant_id: tenant.id
    can :update, Customer, tenant_id: tenant.id

    # Can read studios but not modify them
    can :read, Studio, tenant_id: tenant.id

    # Can read other staff members but not manage them
    can :read, StaffMember, tenant_id: tenant.id

    # Can read tenant and branding info
    can :read, Tenant, id: tenant.id
    can :read, Branding, tenant_id: tenant.id

    # Limited analytics access
    can :view, :basic_analytics

    # Basic expense permissions for all staff
    can :read, Expense, tenant_id: tenant.id
    can :create, Expense, tenant_id: tenant.id

    # Basic sales permissions for all staff
    can :read, Sale, tenant_id: tenant.id
    can :create, Sale, tenant_id: tenant.id

    # Staff can only edit their own expenses if they're in draft status
    can :update, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id, approval_status: 'draft'
    can :destroy, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id, approval_status: 'draft'

    # Cannot manage critical settings
    cannot :manage, TenantUser
    cannot :manage, :billing
    cannot :manage, :subscription
    cannot :delete, Studio
    cannot :delete, StaffMember
  end

  def setup_staff_role_permissions(user, tenant, staff_member)
    case staff_member.role
    when 'customer_service'
      # FIXED: Customer service can manage customers and appointments
      can :manage, Customer, tenant_id: tenant.id
      can :manage, Appointment, tenant_id: tenant.id

      # FIXED: Customer service can manage sales (with studio location restrictions)
      if staff_member.studio_location.present?
        can :manage, Sale, tenant_id: tenant.id, studio_location_id: staff_member.studio_location.id
        can :index, Sale # Allow access to sales index page
      else
        # If no studio assigned, cannot access sales
        cannot :read, Sale
        cannot :manage, Sale
        cannot :index, Sale
      end

      # FIXED: Customer service can only see expenses for their assigned studio location
      if staff_member.studio_location.present?
        can :read, Expense, tenant_id: tenant.id, studio_location_id: staff_member.studio_location.id
        can :index, Expense # Allow access to expense index page
      else
        # If no studio assigned, cannot view any expenses
        cannot :read, Expense
        cannot :index, Expense
      end

    when 'photographer'
      # Photographers can manage their own appointments
      can :manage, Appointment, tenant_id: tenant.id, user_id: user.id
      can :update, Appointment, tenant_id: tenant.id, photographer_id: staff_member.id
      can :read, Customer, tenant_id: tenant.id

      # Can manage their own expenses
      can :update, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id
      can :destroy, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id

    when 'editor'
      # Editors can access completed appointments and customer photos
      can :read, Appointment, tenant_id: tenant.id, status: 'completed'
      can :read, Customer, tenant_id: tenant.id
      can :manage, :photo_editing

      # Can manage their own expenses
      can :update, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id
      can :destroy, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id

    when 'manager'
      # Managers have broader access similar to admin but for operations
      can :manage, Appointment, tenant_id: tenant.id
      can :manage, Customer, tenant_id: tenant.id
      can :read, StaffMember, tenant_id: tenant.id
      can :view, :analytics

      # Managers can manage and approve all expenses
      can :manage, Expense, tenant_id: tenant.id
      can :approve, Expense, tenant_id: tenant.id
      can :reject, Expense, tenant_id: tenant.id

      # Managers can manage all sales
      can :manage, Sale, tenant_id: tenant.id

    when 'receptionist'
      # Receptionists focus on customer service and appointments
      can :manage, Customer, tenant_id: tenant.id
      can :manage, Appointment, tenant_id: tenant.id

      # FIXED: Receptionists can manage sales for their assigned studio location
      if staff_member.studio_location.present?
        can :manage, Sale, tenant_id: tenant.id, studio_location_id: staff_member.studio_location.id
        can :index, Sale
      else
        cannot :read, Sale
        cannot :manage, Sale
        cannot :index, Sale
      end

      # FIXED: Receptionists can only see expenses for their assigned studio location
      if staff_member.studio_location.present?
        can :read, Expense, tenant_id: tenant.id, studio_location_id: staff_member.studio_location.id
        can :index, Expense
      else
        cannot :read, Expense
        cannot :index, Expense
      end

    when 'assistant'
      # Assistants have limited permissions
      can :read, Appointment, tenant_id: tenant.id
      can :read, Customer, tenant_id: tenant.id
      can :create, Appointment, tenant_id: tenant.id

      # Can manage their own expenses only
      can :update, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id
      can :destroy, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id
    end
  end

  def setup_guest_permissions
    # Very limited permissions for guests
    can :read, :public_pages
    can :create, :booking_inquiry # For public booking form

    # No access to any tenant-specific resources
    cannot :manage, :all
  end

  # Convenience methods for checking specific permissions
  def can_manage_tenant?(tenant)
    can?(:manage, Tenant, id: tenant.id)
  end

  def can_view_analytics?
    can?(:view, :analytics) || can?(:view, :basic_analytics)
  end

  def can_manage_billing?
    can?(:manage, :billing)
  end

  def can_export_data?
    can?(:export, :data)
  end

  # Resource-specific permission helpers
  def can_delete_appointment?(appointment)
    can?(:delete, appointment) &&
    (appointment.scheduled_at > 24.hours.from_now || appointment.status == 'pending')
  end

  def can_modify_past_appointment?(appointment)
    can?(:update, appointment) &&
    (appointment.scheduled_at > Time.current || can?(:manage, :all))
  end

  def can_access_customer_data?(customer)
    can?(:read, customer) || can?(:manage, customer)
  end
end
