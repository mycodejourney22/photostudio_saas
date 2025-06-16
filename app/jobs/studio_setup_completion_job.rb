class StudioSetupCompletionJob < ApplicationJob
  def perform(tenant_id)
    tenant = Tenant.find(tenant_id)

    ActsAsTenant.with_tenant(tenant) do
      setup_progress = calculate_setup_progress(tenant)

      if setup_progress[:complete]
        # Mark tenant as fully configured
        tenant.update!(
          status: 'active',
          configured_at: Time.current
        )

        # Send setup completion email to owner
        owner = tenant.tenant_users.owners.first&.user
        SetupCompletionMailer.completed(tenant, owner).deliver_now if owner

        # Enable all features
        enable_all_features(tenant)
      end
    end
  end

  private

  def calculate_setup_progress(tenant)
    checks = {
      has_owner: tenant.tenant_users.owners.exists?,
      has_staff: tenant.staff_members.exists?,
      has_locations: tenant.studio_locations.exists?,
      has_services: tenant.service_packages.exists?,
      has_service_tiers: tenant.service_tiers.exists?
    }

    completed = checks.values.count(true)
    total = checks.size

    {
      checks: checks,
      completed: completed,
      total: total,
      percentage: (completed.to_f / total * 100).round,
      complete: completed == total
    }
  end

  def enable_all_features(tenant)
    tenant.update!(
      features: {
        booking_enabled: true,
        online_payments: true,
        gallery_sharing: true,
        customer_portal: true,
        automated_emails: true,
        analytics: true
      }
    )
  end
end
