class StudioSetupService
  def initialize(tenant)
    @tenant = tenant
  end

  def setup_progress
    ActsAsTenant.with_tenant(@tenant) do
      {
        owner: owner_progress,
        staff: staff_progress,
        locations: locations_progress,
        services: services_progress,
        overall: calculate_overall_progress
      }
    end
  end

  def complete_setup!
    ActsAsTenant.with_tenant(@tenant) do
      @tenant.update!(
        status: 'active',
        configured_at: Time.current
      )

      StudioSetupCompletionJob.perform_later(@tenant.id)
    end
  end

  def setup_complete?
    progress = setup_progress
    progress[:overall][:percentage] >= 80 # 80% threshold for "complete"
  end

  private

  def owner_progress
    has_owner = @tenant.tenant_users.owners.exists?
    {
      complete: has_owner,
      percentage: has_owner ? 100 : 0,
      items: ['Studio owner account']
    }
  end

  def staff_progress
    staff_count = @tenant.staff_members.count
    has_customer_service = @tenant.staff_members.customer_service.exists?

    {
      complete: staff_count > 0 && has_customer_service,
      percentage: staff_count > 0 ? (has_customer_service ? 100 : 50) : 0,
      items: ['Staff members added', 'Customer service role assigned']
    }
  end

  def locations_progress
    location_count = @tenant.studio_locations.active.count
    has_operating_hours = @tenant.studio_locations.any? { |loc| loc.operating_hours.present? }

    {
      complete: location_count > 0 && has_operating_hours,
      percentage: location_count > 0 ? (has_operating_hours ? 100 : 50) : 0,
      items: ['Studio location created', 'Operating hours configured']
    }
  end

  def services_progress
    package_count = @tenant.service_packages.active.count
    tier_count = @tenant.service_tiers.active.count

    {
      complete: package_count > 0 && tier_count > 0,
      percentage: package_count > 0 ? (tier_count > 0 ? 100 : 50) : 0,
      items: ['Service packages created', 'Service tiers configured']
    }
  end

  def calculate_overall_progress
    sections = [owner_progress, staff_progress, locations_progress, services_progress]
    completed_sections = sections.count { |section| section[:complete] }

    {
      complete: completed_sections == sections.size,
      percentage: (completed_sections.to_f / sections.size * 100).round,
      completed_sections: completed_sections,
      total_sections: sections.size
    }
  end
end
