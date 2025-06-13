# Enhanced Demo Seed Data for Booking Workflow
# This file creates comprehensive seed data for the demo tenant
# Usage: ENV['SEED_DATA']='true' rails db:seed

return unless Rails.env.development? || ENV['SEED_DATA'] == 'true'

puts "🌱 Creating enhanced demo seed data for booking workflow..."

# Create demo tenant
demo_tenant = Tenant.find_or_create_by(subdomain: 'demo') do |t|
  t.name = 'Sunset Studios'
  t.email = 'hello@sunsetstudios.com'
  t.plan_type = 'professional'
  t.status = 'active'
  t.verified_at = Time.current
  t.metadata = {
    'setup_completed' => true,
    'onboarding_step' => 'complete'
  }
end

puts "✅ Created demo tenant: #{demo_tenant.name}"

# Create owner user
owner = User.find_or_create_by(email: 'owner@demo.com') do |u|
  u.first_name = 'Sarah'
  u.last_name = 'Johnson'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.phone = '+1 (555) 123-4567'
  u.active = true
  u.confirmed_at = Time.current
end

# Create staff user
photographer = User.find_or_create_by(email: 'photographer@demo.com') do |u|
  u.first_name = 'Mike'
  u.last_name = 'Wilson'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.phone = '+1 (555) 123-4568'
  u.active = true
  u.confirmed_at = Time.current
end

# Create assistant user
assistant = User.find_or_create_by(email: 'assistant@demo.com') do |u|
  u.first_name = 'Emma'
  u.last_name = 'Davis'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.phone = '+1 (555) 123-4569'
  u.active = true
  u.confirmed_at = Time.current
end

# Create tenant-user relationships
TenantUser.find_or_create_by(tenant: demo_tenant, user: owner) do |tu|
  tu.role = 'owner'
  tu.active = true
end

TenantUser.find_or_create_by(tenant: demo_tenant, user: photographer) do |tu|
  tu.role = 'staff'
  tu.active = true
end

TenantUser.find_or_create_by(tenant: demo_tenant, user: assistant) do |tu|
  tu.role = 'staff'
  tu.active = true
end

puts "✅ Created users: Owner, Photographer, Assistant"

# Scope everything to the demo tenant
ActsAsTenant.with_tenant(demo_tenant) do

  # ===== STUDIO LOCATIONS =====
  puts "🏢 Creating studio locations..."

  main_studio = StudioLocation.find_or_create_by(name: 'Main Studio') do |sl|
    sl.description = 'Our flagship studio with professional lighting and spacious shooting area'
    sl.address = '123 Photography Ave'
    sl.city = 'San Francisco'
    sl.state = 'CA'
    sl.postal_code = '94102'
    sl.default_slot_duration = 60
    sl.operating_hours = {
      'monday' => { 'start' => '09:00', 'end' => '18:00' },
      'tuesday' => { 'start' => '09:00', 'end' => '18:00' },
      'wednesday' => { 'start' => '09:00', 'end' => '18:00' },
      'thursday' => { 'start' => '09:00', 'end' => '18:00' },
      'friday' => { 'start' => '09:00', 'end' => '18:00' },
      'saturday' => { 'start' => '10:00', 'end' => '17:00' },
      'sunday' => { 'start' => '11:00', 'end' => '16:00' }
    }
    sl.booking_settings = {
      'buffer_time' => 15,
      'advance_booking_days' => 45,
      'max_daily_bookings' => 8,
      'min_notice_hours' => 24
    }
    sl.active = true
    sl.sort_order = 1
  end

  outdoor_studio = StudioLocation.find_or_create_by(name: 'Outdoor Studio') do |sl|
    sl.description = 'Beautiful outdoor setting with natural light and scenic backdrops'
    sl.address = '456 Golden Gate Park'
    sl.city = 'San Francisco'
    sl.state = 'CA'
    sl.postal_code = '94117'
    sl.default_slot_duration = 90
    sl.operating_hours = {
      'monday' => { 'start' => '', 'end' => '' }, # closed
      'tuesday' => { 'start' => '', 'end' => '' }, # closed
      'wednesday' => { 'start' => '10:00', 'end' => '16:00' },
      'thursday' => { 'start' => '10:00', 'end' => '16:00' },
      'friday' => { 'start' => '10:00', 'end' => '16:00' },
      'saturday' => { 'start' => '09:00', 'end' => '18:00' },
      'sunday' => { 'start' => '09:00', 'end' => '18:00' }
    }
    sl.booking_settings = {
      'buffer_time' => 30,
      'advance_booking_days' => 30,
      'max_daily_bookings' => 4,
      'min_notice_hours' => 48
    }
    sl.active = true
    sl.sort_order = 2
  end

  puts "✅ Created studio locations: #{StudioLocation.count} total"

  # ===== SERVICE PACKAGES =====
  puts "📦 Creating service packages..."

  # Portrait Package
  portrait_package = ServicePackage.find_or_create_by(slug: 'portrait-session') do |sp|
    sp.name = 'Portrait Session'
    sp.description = 'Professional portrait photography for individuals and couples'
    sp.category = 'portrait'
    sp.active = true
    sp.sort_order = 1
    sp.metadata = {
      'duration_range' => '30-120 minutes',
      'ideal_for' => 'Headshots, personal branding, couples',
      'includes' => 'Professional editing, online gallery'
    }
  end

  # Portrait Service Tiers
  portrait_package.service_tiers.find_or_create_by(name: 'Essential Portrait') do |st|
    st.description = 'Perfect for headshots and quick sessions'
    st.price = 199.00
    st.duration_minutes = 30
    st.features = [
      '1 outfit change',
      '15 professionally edited photos',
      'Online gallery access',
      'Basic retouching included'
    ]
    st.active = true
    st.sort_order = 1
  end

  portrait_package.service_tiers.find_or_create_by(name: 'Standard Portrait') do |st|
    st.description = 'Our most popular portrait session'
    st.price = 349.00
    st.duration_minutes = 60
    st.features = [
      '2 outfit changes',
      '30 professionally edited photos',
      'Online gallery with download rights',
      'Advanced retouching',
      '5 printed photos (5x7)'
    ]
    st.active = true
    st.sort_order = 2
  end

  portrait_package.service_tiers.find_or_create_by(name: 'Premium Portrait') do |st|
    st.description = 'Comprehensive portrait experience'
    st.price = 549.00
    st.duration_minutes = 90
    st.features = [
      '3 outfit changes',
      '50 professionally edited photos',
      'Online gallery with download rights',
      'Advanced retouching & skin smoothing',
      '10 printed photos (8x10)',
      'Same-day preview gallery',
      'Makeup consultation included'
    ]
    st.active = true
    st.sort_order = 3
  end

  # Family Package
  family_package = ServicePackage.find_or_create_by(slug: 'family-session') do |sp|
    sp.name = 'Family Session'
    sp.description = 'Capture precious family moments in a comfortable setting'
    sp.category = 'family'
    sp.active = true
    sp.sort_order = 2
    sp.metadata = {
      'duration_range' => '60-120 minutes',
      'ideal_for' => 'Families, children, extended family groups',
      'includes' => 'Multiple poses, candid shots, professional editing'
    }
  end

  # Family Service Tiers
  family_package.service_tiers.find_or_create_by(name: 'Family Essentials') do |st|
    st.description = 'Beautiful family photos for smaller families'
    st.price = 299.00
    st.duration_minutes = 60
    st.features = [
      'Up to 4 family members',
      '25 professionally edited photos',
      'Online gallery access',
      'Multiple pose setups',
      'Props and accessories included'
    ]
    st.active = true
    st.sort_order = 1
  end

  family_package.service_tiers.find_or_create_by(name: 'Extended Family') do |st|
    st.description = 'Perfect for larger families and multiple generations'
    st.price = 449.00
    st.duration_minutes = 90
    st.features = [
      'Up to 8 family members',
      '40 professionally edited photos',
      'Online gallery with download rights',
      'Individual and group shots',
      'Props and seasonal decorations',
      '8 printed photos (5x7)'
    ]
    st.active = true
    st.sort_order = 2
  end

  # Wedding Package
  wedding_package = ServicePackage.find_or_create_by(slug: 'wedding-session') do |sp|
    sp.name = 'Wedding Photography'
    sp.description = 'Engagement sessions and wedding day photography'
    sp.category = 'wedding'
    sp.active = true
    sp.sort_order = 3
    sp.metadata = {
      'duration_range' => '60-240 minutes',
      'ideal_for' => 'Engagements, bridal sessions, intimate weddings',
      'includes' => 'Unlimited shots, artistic editing, timeline planning'
    }
  end

  # Wedding Service Tiers
  wedding_package.service_tiers.find_or_create_by(name: 'Engagement Session') do |st|
    st.description = 'Romantic engagement photography'
    st.price = 399.00
    st.duration_minutes = 60
    st.features = [
      '1-hour session',
      '35 professionally edited photos',
      'Multiple location options within studio',
      'Outfit change encouraged',
      'Online gallery with download rights',
      'Engagement announcement template'
    ]
    st.active = true
    st.sort_order = 1
  end

  wedding_package.service_tiers.find_or_create_by(name: 'Bridal Portrait') do |st|
    st.description = 'Solo bridal session in wedding attire'
    st.price = 599.00
    st.duration_minutes = 90
    st.features = [
      '90-minute session',
      '45 professionally edited photos',
      'Dress fitting assistance',
      'Hair & makeup touch-ups',
      'Multiple backdrop options',
      '12 printed photos (8x10)',
      'Online gallery with download rights'
    ]
    st.active = true
    st.sort_order = 2
  end

  # Event Package
  event_package = ServicePackage.find_or_create_by(slug: 'event-session') do |sp|
    sp.name = 'Event Photography'
    sp.description = 'Corporate events, parties, and special occasions'
    sp.category = 'event'
    sp.active = true
    sp.sort_order = 4
    sp.metadata = {
      'duration_range' => '120-480 minutes',
      'ideal_for' => 'Corporate events, birthday parties, celebrations',
      'includes' => 'Event coverage, candid shots, group photos'
    }
  end

  # Event Service Tiers
  event_package.service_tiers.find_or_create_by(name: 'Small Event') do |st|
    st.description = 'Perfect for intimate gatherings and small parties'
    st.price = 499.00
    st.duration_minutes = 120
    st.features = [
      '2-hour coverage',
      'Up to 20 guests',
      '60 professionally edited photos',
      'Candid and posed shots',
      'Online gallery access',
      'Same-day preview selection'
    ]
    st.active = true
    st.sort_order = 1
  end

  puts "✅ Created service packages: #{ServicePackage.count} total"
  puts "✅ Created service tiers: #{ServiceTier.count} total"

  # ===== LINK PACKAGES TO LOCATIONS =====
  puts "🔗 Linking service packages to studio locations..."

  # Main Studio - all packages available
  [portrait_package, family_package, wedding_package, event_package].each do |package|
    ServicePackageStudioLocation.find_or_create_by(
      service_package: package,
      studio_location: main_studio
    ) do |link|
      link.active = true
    end
  end

  # Outdoor Studio - only portrait, family, and wedding
  [portrait_package, family_package, wedding_package].each do |package|
    ServicePackageStudioLocation.find_or_create_by(
      service_package: package,
      studio_location: outdoor_studio
    ) do |link|
      link.active = true
    end
  end

  puts "✅ Linked packages to studio locations"

  # ===== CUSTOMERS =====
  puts "👥 Creating demo customers..."

  customers_data = [
    {
      first_name: 'Emma',
      last_name: 'Johnson',
      email: 'emma.johnson@email.com',
      phone: '+1 (555) 234-5678',
      address: '456 Market Street, Apt 12',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94102',
      date_of_birth: Date.parse('1990-03-15'),
      preferences: 'Prefers natural lighting, loves outdoor shoots',
      notes: 'Returning customer - had great experience with portrait session'
    },
    {
      first_name: 'David',
      last_name: 'Chen',
      email: 'david.chen@email.com',
      phone: '+1 (555) 345-6789',
      address: '789 Oak Avenue',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94103',
      date_of_birth: Date.parse('1985-07-22'),
      preferences: 'Professional headshots for LinkedIn',
      notes: 'CEO of tech startup, needs professional branding photos'
    },
    {
      first_name: 'Maria',
      last_name: 'Rodriguez',
      email: 'maria.rodriguez@email.com',
      phone: '+1 (555) 456-7890',
      address: '321 Pine Street',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94104',
      date_of_birth: Date.parse('1988-11-08'),
      preferences: 'Family photos with 2 young children',
      notes: 'Children are ages 3 and 6, may need shorter session'
    },
    {
      first_name: 'James',
      last_name: 'Thompson',
      email: 'james.thompson@email.com',
      phone: '+1 (555) 567-8901',
      address: '654 California Street',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94105',
      date_of_birth: Date.parse('1992-05-18'),
      preferences: 'Engagement photos with fiancée',
      notes: 'Planning wedding for next year, wants engagement announcements'
    },
    {
      first_name: 'Lisa',
      last_name: 'Williams',
      email: 'lisa.williams@email.com',
      phone: '+1 (555) 678-9012',
      address: '987 Union Square',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94108',
      date_of_birth: Date.parse('1987-09-25'),
      preferences: 'Corporate headshots for team',
      notes: 'HR manager, booking for 10 team members over 2 days'
    },
    {
      first_name: 'Michael',
      last_name: 'Brown',
      email: 'michael.brown@email.com',
      phone: '+1 (555) 789-0123',
      address: '159 Lombard Street',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94111',
      date_of_birth: Date.parse('1983-12-12'),
      preferences: 'Family reunion photos',
      notes: 'Large family group - 15+ people, needs outdoor space'
    }
  ]

  customers = customers_data.map do |customer_data|
    Customer.find_or_create_by(email: customer_data[:email]) do |c|
      customer_data.each { |key, value| c[key] = value }
      c.active = true
      c.country = 'US'
      c.metadata = {
        'customer_since' => rand(1..24).months.ago,
        'total_sessions' => rand(1..5),
        'referral_source' => ['Google', 'Instagram', 'Word of mouth', 'Yelp', 'Previous client'].sample
      }
    end
  end

  puts "✅ Created customers: #{Customer.count} total"

  # ===== STAFF MEMBERS =====
  puts "👨‍💼 Creating staff member records..."

  # Create staff member records for users
  StaffMember.find_or_create_by(user: photographer) do |sm|
    sm.first_name = photographer.first_name
    sm.last_name = photographer.last_name
    sm.email = photographer.email
    sm.phone = photographer.phone
    sm.role = 'Lead Photographer'
    sm.active = true
    sm.has_login = true
    sm.hourly_rate = 75.00
    sm.hire_date = 2.years.ago.to_date
    sm.skills = ['Portrait Photography', 'Wedding Photography', 'Event Photography', 'Photo Editing']
    sm.notes = 'Specializes in natural light photography and candid moments'
  end

  StaffMember.find_or_create_by(user: assistant) do |sm|
    sm.first_name = assistant.first_name
    sm.last_name = assistant.last_name
    sm.email = assistant.email
    sm.phone = assistant.phone
    sm.role = 'Photography Assistant'
    sm.active = true
    sm.has_login = true
    sm.hourly_rate = 25.00
    sm.hire_date = 8.months.ago.to_date
    sm.skills = ['Lighting Setup', 'Customer Service', 'Equipment Management', 'Basic Editing']
    sm.notes = 'Excellent with children and families, very organized'
  end

  # Create staff-only member (no login)
  StaffMember.find_or_create_by(email: 'freelance@demo.com') do |sm|
    sm.first_name = 'Alex'
    sm.last_name = 'Park'
    sm.phone = '+1 (555) 890-1234'
    sm.role = 'Freelance Photographer'
    sm.active = true
    sm.has_login = false
    sm.hourly_rate = 60.00
    sm.hire_date = 6.months.ago.to_date
    sm.skills = ['Event Photography', 'Group Photos', 'Corporate Photography']
    sm.notes = 'Available for weekend events and large corporate bookings'
  end

  puts "✅ Created staff members: #{StaffMember.count} total"

  # ===== LEGACY STUDIOS (for backward compatibility) =====
  puts "🏢 Creating legacy studio records..."

  Studio.find_or_create_by(name: 'Studio A') do |s|
    s.location = 'Main Floor - Natural Light'
    s.description = 'Large studio with floor-to-ceiling windows and professional lighting equipment'
    s.capacity = 8
    s.equipment = 'Profoto lighting kit, seamless backdrops, reflectors, props collection'
    s.active = true
    s.metadata = {
      'square_footage' => 800,
      'ceiling_height' => 12,
      'natural_light' => true,
      'accessible' => true
    }
  end

  Studio.find_or_create_by(name: 'Studio B') do |s|
    s.location = 'Second Floor - Portrait Specialist'
    s.description = 'Intimate studio perfect for headshots and individual portraits'
    s.capacity = 4
    s.equipment = 'Portrait lighting setup, various backdrops, makeup station'
    s.active = true
    s.metadata = {
      'square_footage' => 400,
      'ceiling_height' => 10,
      'natural_light' => false,
      'accessible' => true
    }
  end

  puts "✅ Created legacy studios: #{Studio.count} total"

  # ===== APPOINTMENTS =====
  puts "📅 Creating comprehensive appointment data..."

  service_tiers = ServiceTier.all.to_a
  photographers = [photographer, assistant]
  studios = Studio.all.to_a

  # Helper method to create appointments
  def create_appointment(customer:, photographer:, studio:, studio_location:, service_tier:, scheduled_at:, status:, notes: nil)
    Appointment.find_or_create_by(
      customer: customer,
      user: photographer,
      scheduled_at: scheduled_at
    ) do |a|
      a.studio = studio
      a.studio_location = studio_location
      a.service_tier = service_tier
      a.duration_minutes = service_tier.duration_minutes
      a.price = service_tier.price
      a.session_type = service_tier.service_package.category
      a.status = status
      a.payment_status = status.in?(['completed', 'confirmed']) ? 'paid' : 'unpaid'
      a.booking_source = 'online'
      a.notes = notes || "Demo #{status} appointment"
      a.special_requirements = case service_tier.service_package.category
      when 'family'
        'Please have props ready for children'
      when 'wedding'
        'Bring bouquet and any special jewelry'
      when 'event'
        'Coordinate with event organizer for timeline'
      else
        nil
      end
    end
  end

  # === PAST APPOINTMENTS (Last 30 days) ===
  puts "📅 Creating past appointments..."

  15.times do |i|
    date = rand(30.days.ago..7.days.ago).to_date
    time_slot = [9, 10, 11, 13, 14, 15, 16].sample
    scheduled_time = date.beginning_of_day + time_slot.hours

    customer = customers.sample
    photographer_user = photographers.sample
    service_tier = service_tiers.sample
    studio = studios.sample
    studio_location = [main_studio, outdoor_studio].sample

    create_appointment(
      customer: customer,
      photographer: photographer_user,
      studio: studio,
      studio_location: studio_location,
      service_tier: service_tier,
      scheduled_at: scheduled_time,
      status: 'completed',
      notes: "Completed session #{i + 1} - Great results, customer very satisfied"
    )
  end

  # === TODAY'S APPOINTMENTS ===
  puts "📅 Creating today's appointments..."

  # Morning appointment - 9:00 AM
  create_appointment(
    customer: customers.find { |c| c.first_name == 'Emma' },
    photographer: photographer,
    studio: studios.first,
    studio_location: main_studio,
    service_tier: portrait_package.service_tiers.find_by(name: 'Standard Portrait'),
    scheduled_at: Date.current.beginning_of_day + 9.hours,
    status: 'confirmed',
    notes: 'Professional headshots for LinkedIn profile - bring 2 outfit options'
  )

  # Mid-morning appointment - 11:30 AM
  create_appointment(
    customer: customers.find { |c| c.first_name == 'Maria' },
    photographer: assistant,
    studio: studios.last,
    studio_location: main_studio,
    service_tier: family_package.service_tiers.find_by(name: 'Family Essentials'),
    scheduled_at: Date.current.beginning_of_day + 11.5.hours,
    status: 'confirmed',
    notes: 'Family session with 2 young children - have snacks and toys ready'
  )

  # Afternoon appointment - 2:00 PM
  create_appointment(
    customer: customers.find { |c| c.first_name == 'James' },
    photographer: photographer,
    studio: studios.first,
    studio_location: outdoor_studio,
    service_tier: wedding_package.service_tiers.find_by(name: 'Engagement Session'),
    scheduled_at: Date.current.beginning_of_day + 14.hours,
    status: 'pending',
    notes: 'Engagement session - couple bringing ring for detail shots'
  )

  # === UPCOMING APPOINTMENTS (Next 2 weeks) ===
  puts "📅 Creating upcoming appointments..."

  10.times do |i|
    # Create appointments spread over next 2 weeks
    date = rand(1.day.from_now..14.days.from_now).to_date
    time_slot = [9, 10, 11, 13, 14, 15, 16].sample
    scheduled_time = date.beginning_of_day + time_slot.hours

    customer = customers.sample
    photographer_user = photographers.sample
    service_tier = service_tiers.sample
    studio = studios.sample
    studio_location = [main_studio, outdoor_studio].sample

    # Mix of confirmed and pending
    status = ['confirmed', 'pending'].sample

    create_appointment(
      customer: customer,
      photographer: photographer_user,
      studio: studio,
      studio_location: studio_location,
      service_tier: service_tier,
      scheduled_at: scheduled_time,
      status: status,
      notes: "Upcoming #{status} appointment - #{service_tier.name}"
    )
  end

  puts "✅ Created appointments: #{Appointment.count} total"

  # ===== BRANDING =====
  puts "🎨 Setting up branding..."

  branding = Branding.find_or_create_by(tenant: demo_tenant) do |b|
    b.primary_color = '#6366f1'
    b.secondary_color = '#8b5cf6'
    b.font_family = 'Inter'
    b.welcome_message = 'Welcome to Sunset Studios! We specialize in capturing life\'s most precious moments with artistic flair and professional excellence. Our experienced team creates stunning portraits, family photos, and event photography that you\'ll treasure forever.'
    b.settings = {
      'show_pricing' => true,
      'allow_online_booking' => true,
      'require_deposit' => false,
      'send_reminders' => true,
      'gallery_watermark' => true
    }
  end

  puts "✅ Updated branding and settings"

  # ===== SUMMARY STATISTICS =====
  puts "\n" + "="*50
  puts "🎉 Enhanced demo seed data creation complete!"
  puts "="*50

  # Calculate some stats for display
  total_revenue = Appointment.completed.sum(:price)
  this_week_bookings = Appointment.this_week.count
  today_appointments = Appointment.today.count

  puts <<~SUMMARY

    📊 Demo Tenant Overview:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Studio: #{demo_tenant.name}
    Subdomain: #{demo_tenant.subdomain}
    URL: http://demo.localhost:3000

    👥 Users Created:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    • Owner: owner@demo.com
    • Photographer: photographer@demo.com
    • Assistant: assistant@demo.com
    🔑 Password for all: password123

    🏢 Studio Setup:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    • Studio Locations: #{StudioLocation.count}
    • Service Packages: #{ServicePackage.count}
    • Service Tiers: #{ServiceTier.count}
    • Legacy Studios: #{Studio.count}

    👥 Customer Data:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    • Total Customers: #{Customer.count}
    • Staff Members: #{StaffMember.count}

    📅 Appointment Data:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    • Total Appointments: #{Appointment.count}
    • Today's Schedule: #{today_appointments}
    • This Week: #{this_week_bookings}
    • Completed Sessions: #{Appointment.completed.count}
    • Total Revenue: $#{total_revenue.to_f}

    🎯 Features Ready to Test:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ✅ Multi-step booking workflow
    ✅ Service packages and tiers
    ✅ Studio location management
    ✅ Customer management system
    ✅ Appointment scheduling
    ✅ Staff role management
    ✅ Dashboard with real metrics
    ✅ Online booking system
    ✅ Payment workflow integration
    ✅ Responsive design

    🌐 Booking Flow Test:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    1. Visit: http://demo.localhost:3000/book
    2. Select studio location
    3. Choose service package
    4. Pick service tier
    5. Select date & time
    6. Enter customer details
    7. Process payment

    🚀 Next Steps:
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
    • Test the complete booking workflow
    • Verify dashboard metrics
    • Check appointment management
    • Test customer creation flow
    • Validate service package pricing
    • Confirm payment integration

  SUMMARY

end

puts "🎯 Demo environment is fully configured and ready for testing!"
puts "📱 Access your demo at: http://demo.localhost:3000"
puts ""
