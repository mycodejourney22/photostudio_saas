# app/models/ability.rb
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
    # Staff can manage appointments and customers, but limited access to settings
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

    # Cannot manage critical settings
    cannot :manage, TenantUser
    cannot :manage, :billing
    cannot :manage, :subscription
    cannot :delete, Studio
    cannot :delete, StaffMember

    # Check if staff member has additional permissions
    setup_staff_role_permissions(user, tenant)
  end

  def setup_staff_role_permissions(user, tenant)
    staff_member = StaffMember.find_by(user: user, tenant: tenant)
    return unless staff_member

    case staff_member.role
    when 'customer_service'
      # Customer service can manage customers and appointments
      can :manage, Customer, tenant_id: tenant.id
      can :manage, Appointment, tenant_id: tenant.id
    when 'photographer'
      # Photographers can manage their own appointments
      can :manage, Appointment, tenant_id: tenant.id, user_id: user.id
      can :update, Appointment, tenant_id: tenant.id, photographer_id: staff_member.id
      can :read, Customer, tenant_id: tenant.id
    when 'editor'
      # Editors can access completed appointments and customer photos
      can :read, Appointment, tenant_id: tenant.id, status: 'completed'
      can :read, Customer, tenant_id: tenant.id
      can :manage, :photo_editing
    when 'manager'
      # Managers have broader access similar to admin but for operations
      can :manage, Appointment, tenant_id: tenant.id
      can :manage, Customer, tenant_id: tenant.id
      can :read, StaffMember, tenant_id: tenant.id
      can :view, :analytics
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
