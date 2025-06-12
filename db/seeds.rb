# db/seeds.rb
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.

# Only seed in development or if explicitly requested
return unless Rails.env.development? || ENV['SEED_DATA'] == 'true'

puts "🌱 Seeding development data..."

# Create a sample tenant
tenant = Tenant.find_or_create_by(subdomain: 'demo') do |t|
  t.name = 'Demo Photography Studio'
  t.email = 'demo@photostudio.com'
  t.plan_type = 'professional'
  t.status = 'active'
  t.verified_at = Time.current
end

puts "✅ Created tenant: #{tenant.name}"

# Create owner user
owner = User.find_or_create_by(email: 'owner@demo.com') do |u|
  u.first_name = 'Sarah'
  u.last_name = 'Johnson'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.phone = '+1234567890'
  u.active = true
  u.confirmed_at = Time.current
end

# Create tenant-user relationship
TenantUser.find_or_create_by(tenant: tenant, user: owner) do |tu|
  tu.role = 'owner'
  tu.active = true
end

puts "✅ Created owner: #{owner.full_name}"

# Create staff user
staff = User.find_or_create_by(email: 'staff@demo.com') do |u|
  u.first_name = 'Mike'
  u.last_name = 'Wilson'
  u.password = 'password123'
  u.password_confirmation = 'password123'
  u.phone = '+1234567891'
  u.active = true
  u.confirmed_at = Time.current
end

TenantUser.find_or_create_by(tenant: tenant, user: staff) do |tu|
  tu.role = 'staff'
  tu.active = true
end

puts "✅ Created staff: #{staff.full_name}"

# Scope everything to the tenant
ActsAsTenant.with_tenant(tenant) do
  # Create studios
  studio_a = Studio.find_or_create_by(name: 'Studio A') do |s|
    s.location = 'Main Floor'
    s.description = 'Large studio with natural lighting'
    s.capacity = 6
    s.equipment = 'Professional lighting kit, backdrops, props'
    s.active = true
  end

  studio_b = Studio.find_or_create_by(name: 'Studio B') do |s|
    s.location = 'Second Floor'
    s.description = 'Intimate studio perfect for portraits'
    s.capacity = 4
    s.equipment = 'Portrait lighting, various backdrops'
    s.active = true
  end

  puts "✅ Created studios: #{Studio.count} total"

  # Create sample customers
  customers_data = [
    {
      first_name: 'Emma',
      last_name: 'Davis',
      email: 'emma.davis@email.com',
      phone: '+1234567892',
      address: '123 Oak Street',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94102'
    },
    {
      first_name: 'James',
      last_name: 'Rodriguez',
      email: 'james.rodriguez@email.com',
      phone: '+1234567893',
      address: '456 Pine Avenue',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94103'
    },
    {
      first_name: 'Lisa',
      last_name: 'Chen',
      email: 'lisa.chen@email.com',
      phone: '+1234567894',
      address: '789 Market Street',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94104'
    },
    {
      first_name: 'David',
      last_name: 'Thompson',
      email: 'david.thompson@email.com',
      phone: '+1234567895',
      address: '321 Mission Street',
      city: 'San Francisco',
      state: 'CA',
      zip_code: '94105'
    }
  ]

  customers = customers_data.map do |customer_data|
    Customer.find_or_create_by(email: customer_data[:email]) do |c|
      customer_data.each { |key, value| c[key] = value }
      c.active = true
      c.notes = 'Created via seeds'
    end
  end

  puts "✅ Created customers: #{Customer.count} total"

  # Create sample appointments
  session_types = %w[portrait wedding family event commercial]
  statuses = %w[confirmed pending completed]

  # Past appointments
  10.times do |i|
    # Fix: Generate random date properly
    start_date = 30.days.ago.to_date
    end_date = 7.days.ago.to_date
    date = rand(start_date..end_date)

    customer = customers.sample
    photographer = [owner, staff].sample
    studio = [studio_a, studio_b].sample

    Appointment.find_or_create_by(
      customer: customer,
      user: photographer,
      scheduled_at: date.beginning_of_day + [9, 10, 11, 14, 15, 16].sample.hours
    ) do |a|
      a.studio = studio
      a.duration_minutes = [60, 90, 120, 180].sample
      a.price = [150, 200, 300, 450, 600].sample
      a.session_type = session_types.sample
      a.status = 'completed'
      a.notes = "Completed session #{i + 1}"
    end
  end

  # Today's appointments
  today_times = [
    { hour: 9, customer: customers[0], photographer: owner },
    { hour: 11.5, customer: customers[1], photographer: staff },
    { hour: 14, customer: customers[2], photographer: owner }
  ]

  today_times.each_with_index do |slot, i|
    scheduled_time = Date.current.beginning_of_day + slot[:hour].hours

    Appointment.find_or_create_by(
      customer: slot[:customer],
      user: slot[:photographer],
      scheduled_at: scheduled_time
    ) do |a|
      a.studio = [studio_a, studio_b].sample
      a.duration_minutes = [60, 90, 120].sample
      a.price = [200, 300, 450].sample
      a.session_type = ['portrait', 'family', 'event'].sample  # Fixed: removed 'engagement'
      a.status = ['confirmed', 'pending'].sample
      a.notes = "Today's session #{i + 1}"
    end
  end

  # Future appointments
  5.times do |i|
    # Fix: Generate random future date properly
    start_date = 1.day.from_now.to_date
    end_date = 14.days.from_now.to_date
    date = rand(start_date..end_date)

    customer = customers.sample
    photographer = [owner, staff].sample

    Appointment.find_or_create_by(
      customer: customer,
      user: photographer,
      scheduled_at: date.beginning_of_day + [9, 10, 11, 14, 15, 16].sample.hours
    ) do |a|
      a.studio = [studio_a, studio_b].sample
      a.duration_minutes = [60, 90, 120].sample
      a.price = [200, 300, 450].sample
      a.session_type = session_types.sample
      a.status = ['confirmed', 'pending'].sample
      a.notes = "Upcoming session #{i + 1}"
    end
  end

  puts "✅ Created appointments: #{Appointment.count} total"

  # Update branding
  if tenant.branding
    tenant.branding.update!(
      primary_color: '#6366f1',
      secondary_color: '#8b5cf6',
      font_family: 'Inter',
      welcome_message: 'Welcome to Demo Photography Studio! We specialize in capturing life\'s most precious moments with artistic flair and professional excellence.'
    )
    puts "✅ Updated branding"
  end
end

puts <<~MESSAGE

🎉 Seeding complete!

Demo tenant details:
- Subdomain: demo
- URL: http://demo.localhost:3000 (development)
- Owner: owner@demo.com / password123
- Staff: staff@demo.com / password123

You can now:
1. Visit http://demo.localhost:3000
2. Sign in with either account
3. Explore the dashboard with sample data

MESSAGE
