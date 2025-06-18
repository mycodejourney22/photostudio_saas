# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user, tenant)
    user ||= User.new
    @tenant = tenant
    @user = user

    if user.persisted? && tenant.present?
      setup_tenant_permissions(user, tenant)
    else
      setup_guest_permissions
    end
  end

  private

  def setup_tenant_permissions(user, tenant)
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
    can :manage, Tenant, id: tenant.id
    can :manage, TenantUser, tenant_id: tenant.id
    can :manage, Branding, tenant_id: tenant.id
    can :manage, :billing
    can :manage, :subscription
    can :view, :analytics
    can :export, :data
  end

  def setup_admin_permissions(user, tenant)
    # Admin can manage most resources across all studio locations
    can :manage, Appointment, tenant_id: tenant.id
    can :manage, Customer, tenant_id: tenant.id
    can :manage, Studio, tenant_id: tenant.id
    can :manage, StaffMember, tenant_id: tenant.id
    can :manage, Sale, tenant_id: tenant.id
    can :manage, Expense, tenant_id: tenant.id
    can :manage, StudioLocation, tenant_id: tenant.id
    can :manage, ServicePackage, tenant_id: tenant.id
    can :manage, ServiceTier
    can :manage, Branding, tenant_id: tenant.id

    can :read, Tenant, id: tenant.id
    can :read, TenantUser, tenant_id: tenant.id
    can :view, :analytics
    can :export, :data

    cannot :manage, :billing
    cannot :manage, :subscription
    cannot :delete, Tenant
  end

  def setup_staff_permissions(user, tenant)
    staff_member = user.current_staff_member(tenant)

    # Basic permissions for all staff
    can :read, Tenant, id: tenant.id
    can :read, Branding, tenant_id: tenant.id
    can :read, ServicePackage, tenant_id: tenant.id
    can :read, ServiceTier
    can :view, :basic_analytics

    if staff_member&.studio_location.present?
      setup_studio_specific_permissions(user, tenant, staff_member)
    else
      setup_general_staff_permissions(user, tenant, staff_member)
    end
  end

  def setup_studio_specific_permissions(user, tenant, staff_member)
    studio_location = staff_member.studio_location

    # Studio-specific permissions
    can :manage, Appointment, tenant_id: tenant.id, studio_location_id: studio_location.id
    can :manage, Sale, tenant_id: tenant.id, studio_location_id: studio_location.id  # Now works!
    can :read, Expense, tenant_id: tenant.id, studio_location_id: studio_location.id
    can :create, Expense, tenant_id: tenant.id
    can :update, Expense, tenant_id: tenant.id, staff_member_id: staff_member.id

    # Customers - broader access needed since they can serve multiple studios
    can :read, Customer, tenant_id: tenant.id
    can :create, Customer, tenant_id: tenant.id
    can :update, Customer, tenant_id: tenant.id

    # Staff and studios
    can :read, StaffMember, tenant_id: tenant.id, studio_location_id: studio_location.id
    can :read, StudioLocation, tenant_id: tenant.id, id: studio_location.id
    can :read, Studio, tenant_id: tenant.id

    # Role-specific permissions
    setup_staff_role_permissions(user, tenant, staff_member)
  end

  def setup_general_staff_permissions(user, tenant, staff_member)
    # For staff not assigned to specific studios
    can :manage, Appointment, tenant_id: tenant.id
    can :manage, Sale, tenant_id: tenant.id
    can :read, Customer, tenant_id: tenant.id
    can :create, Customer, tenant_id: tenant.id
    can :update, Customer, tenant_id: tenant.id
    can :read, StaffMember, tenant_id: tenant.id
    can :read, StudioLocation, tenant_id: tenant.id
    can :read, Studio, tenant_id: tenant.id
    can :read, Expense, tenant_id: tenant.id
    can :create, Expense, tenant_id: tenant.id

    if staff_member
      setup_staff_role_permissions(user, tenant, staff_member)
    end
  end

  def setup_staff_role_permissions(user, tenant, staff_member)
    case staff_member.role
    when 'manager'
      # Managers can see all data for their studio (or all if not studio-assigned)
      if staff_member.studio_location
        can :manage, StaffMember, tenant_id: tenant.id, studio_location_id: staff_member.studio_location.id
        can :manage, Expense, tenant_id: tenant.id, studio_location_id: staff_member.studio_location.id
      else
        can :manage, StaffMember, tenant_id: tenant.id
        can :manage, Expense, tenant_id: tenant.id
      end
      can :manage, Customer, tenant_id: tenant.id
      can :view, :analytics

    when 'customer_service'
      can :manage, Customer, tenant_id: tenant.id
      # Sales and appointments already handled by studio-specific permissions

    when 'photographer'
      can :update, Appointment, tenant_id: tenant.id, assigned_photographer_id: staff_member.id

    when 'editor'
      can :read, Appointment, tenant_id: tenant.id, status: 'completed'
      can :manage, :photo_editing

    when 'owner'
      can :manage, Customer, tenant_id: tenant.id
      can :manage, StaffMember, tenant_id: tenant.id
      can :manage, Expense, tenant_id: tenant.id
      can :view, :analytics
    end
  end

  def setup_guest_permissions
    can :read, :public_pages
    can :create, :booking_inquiry
    cannot :manage, :all
  end
end
