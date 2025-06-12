# lib/tasks/demo.rake
namespace :demo do
  desc "Reset and recreate demo data"
  task reset: :environment do
    puts "🔄 Resetting demo data..."

    # Find demo tenant
    demo_tenant = Tenant.find_by(subdomain: 'demo')

    if demo_tenant
      puts "🗑️  Removing existing demo data..."

      # Remove in correct order to avoid foreign key constraints
      ActsAsTenant.with_tenant(demo_tenant) do
        Appointment.destroy_all
        Customer.destroy_all
        Studio.destroy_all
      end

      TenantUser.where(tenant: demo_tenant).destroy_all
      User.where(email: ['owner@demo.com', 'staff@demo.com']).destroy_all
      demo_tenant.destroy
    end

    puts "🌱 Creating fresh demo data..."
    ENV['SEED_DATA'] = 'true'
    Rails.application.load_seed

    puts "✅ Demo reset complete!"
  end

  desc "Create demo data (if it doesn't exist)"
  task create: :environment do
    if Tenant.exists?(subdomain: 'demo')
      puts "Demo data already exists. Use 'demo:reset' to recreate."
    else
      ENV['SEED_DATA'] = 'true'
      Rails.application.load_seed
    end
  end

  desc "Show demo login information"
  task info: :environment do
    demo_tenant = Tenant.find_by(subdomain: 'demo')

    if demo_tenant
      puts <<~INFO

        📸 Demo Photography Studio

        URL: http://demo.localhost:3000

        Login Credentials:
        👑 Owner: owner@demo.com / password123
        👤 Staff: staff@demo.com / password123

        Features to test:
        ✅ Dashboard with real data
        ✅ Today's appointments
        ✅ Customer management
        ✅ Studio management
        ✅ Multi-user access

      INFO
    else
      puts "❌ Demo data not found. Run 'rails demo:create' first."
    end
  end
end
