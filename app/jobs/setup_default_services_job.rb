# app/jobs/setup_default_services_job.rb
class SetupDefaultServicesJob < ApplicationJob
  def perform(tenant_id)
    tenant = Tenant.find(tenant_id)

    ActsAsTenant.with_tenant(tenant) do
      create_default_studio_location(tenant)
      create_default_service_packages(tenant)
    end
  end

  private

  def create_default_studio_location(tenant)
    studio_location = tenant.studio_locations.create!(
      name: 'Main Studio',
      description: 'Primary photography studio',
      default_slot_duration: 60,
      operating_hours: {
        'monday' => { 'start' => '09:00', 'end' => '17:00' },
        'tuesday' => { 'start' => '09:00', 'end' => '17:00' },
        'wednesday' => { 'start' => '09:00', 'end' => '17:00' },
        'thursday' => { 'start' => '09:00', 'end' => '17:00' },
        'friday' => { 'start' => '09:00', 'end' => '17:00' },
        'saturday' => { 'start' => '10:00', 'end' => '16:00' },
        'sunday' => { 'start' => '', 'end' => '' }
      },
      booking_settings: {
        'buffer_time' => 15,
        'advance_booking_days' => 30,
        'max_daily_bookings' => 8
      }
    )

    # create_default_service_packages(tenant, studio_location)
  end

  def create_default_service_packages(tenant, studio_location = nil)
    # Portrait Package
    portrait_package = tenant.service_packages.create!(
      name: 'Portrait Session',
      slug: 'portrait-session',
      description: 'Professional portrait photography',
      category: 'portrait',
      sort_order: 1
    )

    # Portrait tiers
    portrait_package.service_tiers.create!([
      {
        name: 'Basic Portrait',
        description: '1 outfit, 30-minute session',
        price: 150,
        duration_minutes: 30,
        features: ['1 outfit change', '15 edited photos', 'Online gallery'],
        sort_order: 1
      },
      {
        name: 'Standard Portrait',
        description: '2 outfits, 1-hour session',
        price: 250,
        duration_minutes: 60,
        features: ['2 outfit changes', '25 edited photos', 'Online gallery', '5 printed photos'],
        sort_order: 2
      },
      {
        name: 'Premium Portrait',
        description: '3 outfits, 90-minute session',
        price: 350,
        duration_minutes: 90,
        features: ['3 outfit changes', '40 edited photos', 'Online gallery', '10 printed photos', 'Same-day editing'],
        sort_order: 3
      }
    ])

    # Family Package
    family_package = tenant.service_packages.create!(
      name: 'Family Session',
      slug: 'family-session',
      description: 'Family and group photography',
      category: 'family',
      sort_order: 2
    )

    family_package.service_tiers.create!([
      {
        name: 'Family Basic',
        description: 'Perfect for small families',
        price: 200,
        duration_minutes: 45,
        features: ['Up to 4 people', '20 edited photos', 'Online gallery'],
        sort_order: 1
      },
      {
        name: 'Family Extended',
        description: 'Great for larger families',
        price: 300,
        duration_minutes: 75,
        features: ['Up to 8 people', '30 edited photos', 'Online gallery', '8 printed photos'],
        sort_order: 2
      }
    ])

    # Associate packages with studio location
    if studio_location
      [portrait_package, family_package].each do |package|
        ServicePackageStudioLocation.create!(
          service_package: package,
          studio_location: studio_location,
          active: true
        )
      end
    end
  end
end
